# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "docker_images" {
  repository_id = "whatwebuy-images"
  location      = var.gcp_region
  description   = "Docker image repository for WhatWeBuy services"
  format        = "DOCKER"

  depends_on = [
    google_project_service.required_apis
  ]
}

# IAM binding to allow GitHub Actions to push images
# This grants the service account permission to write to Artifact Registry
resource "google_artifact_registry_repository_iam_member" "github_actions_writer" {
  repository = google_artifact_registry_repository.docker_images.name
  location   = google_artifact_registry_repository.docker_images.location
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_actions.email}"
}

# Allow Cloud Run service accounts to pull images
resource "google_artifact_registry_repository_iam_member" "cloudrun_reader" {
  for_each = toset([
    google_service_account.catalog_products.email,
    google_service_account.catalog_categories.email,
    google_service_account.consumer_transactions.email,
    google_service_account.consumer_enrich.email,
    google_service_account.webapp.email,
  ])

  repository = google_artifact_registry_repository.docker_images.name
  location   = google_artifact_registry_repository.docker_images.location
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${each.value}"
}
