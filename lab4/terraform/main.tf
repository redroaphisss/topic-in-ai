locals {
  image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.lab.repository_id}/${var.name_prefix}-api:${var.image_tag}"
}

# --- APIs (idempotent; safe if already enabled) ---

resource "google_project_service" "services" {
  for_each = toset([
    "compute.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

# --- Private container registry ---

resource "google_artifact_registry_repository" "lab" {
  location      = var.region
  repository_id = "${var.name_prefix}-repo"
  description   = "Lecture 4 lab images (private)"
  format        = "DOCKER"

  depends_on = [google_project_service.services]
}

# --- Runtime identity (pull from Artifact Registry) ---

resource "google_service_account" "vm" {
  account_id   = "${var.name_prefix}-vm"
  display_name = "Lecture 4 lab API VM"
}

# Add the key value separately with gcloud; keep it out of Terraform state.
resource "google_secret_manager_secret" "openai" {
  secret_id = "${var.name_prefix}-openai-key"
  replication {
    auto {}
  }
  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_iam_member" "vm_reader" {
  secret_id = google_secret_manager_secret.openai.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_artifact_registry_repository_iam_member" "vm_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.lab.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.vm.email}"
}

# --- Firewall: one API port ---

resource "google_compute_firewall" "api" {
  name    = "${var.name_prefix}-allow-${var.api_port}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = [tostring(var.api_port)]
  }

  source_ranges = [var.allow_cidr]
  target_tags   = ["${var.name_prefix}-api"]

  depends_on = [google_project_service.services]
}

# --- GCE VM with 1× NVIDIA T4 + Docker pull/run on boot ---

resource "google_compute_instance" "api" {
  name         = "${var.name_prefix}-t4"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["${var.name_prefix}-api"]

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = 50
      type  = "pd-balanced"
    }
  }

  guest_accelerator {
    type  = var.gpu_type
    count = 1
  }

  # Required for GPU VMs
  scheduling {
    on_host_maintenance = "TERMINATE"
    automatic_restart   = true
  }

  network_interface {
    network = "default"
    access_config {} # ephemeral public IP for lab curl demos
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    # Deep Learning images often install drivers on first boot; give them a minute.
    install-nvidia-driver = "True"
  }

  metadata_startup_script = <<-EOT
    #!/usr/bin/env bash
    set -euxo pipefail
    exec > >(tee -a /var/log/${var.name_prefix}-startup.log) 2>&1

    IMAGE="${local.image}"
    PORT="${var.api_port}"

    # Wait briefly for GPU drivers on first boot (DLVM / install-nvidia-driver).
    for i in $(seq 1 30); do
      if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
        nvidia-smi -L
        break
      fi
      sleep 10
    done

    if ! command -v docker >/dev/null 2>&1; then
      curl -fsSL https://get.docker.com | sh
      systemctl enable --now docker
    fi

    # NVIDIA Container Toolkit (no-op if already present on the image).
    if ! docker info 2>/dev/null | grep -qi nvidia; then
      distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
      curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
      curl -fsSL "https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list" \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
      apt-get update
      apt-get install -y nvidia-container-toolkit
      nvidia-ctk runtime configure --runtime=docker
      systemctl restart docker
    fi

    # Auth to Artifact Registry via the VM service account.
    gcloud auth configure-docker ${var.region}-docker.pkg.dev --quiet

    docker pull "$IMAGE"
    docker rm -f l4-api >/dev/null 2>&1 || true
    docker run -d --name l4-api --restart unless-stopped \
      --gpus all \
      -p "$PORT:$PORT" \
      -e PORT="$PORT" \
      -e OPENAI_SECRET_VERSION="${google_secret_manager_secret.openai.id}/versions/latest" \
      -v rag-index:/data \
      "$IMAGE"
  EOT

  depends_on = [
    google_project_service.services,
    google_artifact_registry_repository_iam_member.vm_reader,
    google_secret_manager_secret_iam_member.vm_reader,
    google_compute_firewall.api,
  ]
}
