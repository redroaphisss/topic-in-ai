output "artifact_registry_repo" {
  description = "Artifact Registry repository ID."
  value       = google_artifact_registry_repository.lab.repository_id
}

output "image" {
  description = "Full image reference to build/push (tag from var.image_tag)."
  value       = local.image
}

output "instance_name" {
  value = google_compute_instance.api.name
}

output "external_ip" {
  description = "Public IP for curl demos."
  value       = google_compute_instance.api.network_interface[0].access_config[0].nat_ip
}

output "health_url" {
  value = "http://${google_compute_instance.api.network_interface[0].access_config[0].nat_ip}:${var.api_port}/healthz"
}

output "predict_curl" {
  description = "Example request to the homework RAG API (legacy output name)."
  value       = "curl -sS -X POST http://${google_compute_instance.api.network_interface[0].access_config[0].nat_ip}:${var.api_port}/api/ask -H 'Content-Type: application/json' -d '{\"question\":\"How does RAG use embeddings?\"}'"
}

output "openai_secret_id" {
  value = google_secret_manager_secret.openai.secret_id
}

output "destroy_reminder" {
  value = "Idle T4 VMs burn credits — run: terraform destroy"
}
