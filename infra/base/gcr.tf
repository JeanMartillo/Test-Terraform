resource "google_artifact_registry_repository" "repository" {
  provider      = google-beta
  location      = var.region
  repository_id = "images"
  description   = "Repository for storing JOI News Docker images"
  format        = "DOCKER"
}

# Grant default compute service account read access to Artifact Registry
data "google_compute_default_service_account" "default" {}

resource "google_artifact_registry_repository_iam_member" "default_reader" {
  provider   = google-beta
  location   = google_artifact_registry_repository.repository.location
  repository = google_artifact_registry_repository.repository.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

locals {
  # Use the configured region instead of hardcoding "us-central1"
  gcr_url = "${var.region}-docker.pkg.dev/${var.project}/${google_artifact_registry_repository.repository.repository_id}"
}

resource "local_file" "gcr" {
  filename = "${path.module}/../gcr-url.txt"
  content  = local.gcr_url
}

output "repository_base_url" {
  description = "Base URL for pushing and pulling Docker images"
  value       = local.gcr_url
}
