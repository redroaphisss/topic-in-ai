variable "project_id" {
  description = "GCP project ID (student credits project)."
  type        = string
}

variable "region" {
  description = "Region for Artifact Registry (and related resources)."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone that offers nvidia-tesla-t4 in your project."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Short prefix for resource names."
  type        = string
  default     = "l4-lab"
}

variable "machine_type" {
  description = "GCE machine type compatible with attaching 1× T4."
  type        = string
  default     = "n1-standard-4"
}

variable "boot_image" {
  description = "Deep Learning / GPU-ready image that includes NVIDIA drivers."
  type        = string
  # Supported families: https://cloud.google.com/deep-learning-vm/docs/images
  # Verify availability with gcloud compute images describe-from-family FAMILY
  #   --project=deeplearning-platform-release
  default = "projects/deeplearning-platform-release/global/images/family/pytorch-2-9-cu129-ubuntu-2204-nvidia-580"
}

variable "enable_gpu" {
  description = "Attach a T4 GPU; requires eligible paid billing and GPU quota. The remote-model RAG app does not need it."
  type        = bool
  default     = false
}

variable "gpu_type" {
  description = "Accelerator type (must be a GPU — not a TPU)."
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "api_port" {
  description = "Host/container port for the API."
  type        = number
  default     = 8080
}

variable "image_tag" {
  description = "Container image tag pushed to Artifact Registry (e.g. lab)."
  type        = string
  default     = "lab"
}

variable "allow_cidr" {
  description = "Who may hit the API. Lab default is open; tighten for real use."
  type        = string
  default     = "0.0.0.0/0"
}
