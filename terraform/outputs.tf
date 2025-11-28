output "firestore_database_name" {
  description = "Firestore database name"
  value       = google_firestore_database.main.name
}

output "storage_bucket_name" {
  description = "Cloud Storage bucket name for files"
  value       = google_storage_bucket.files.name
}

output "cloud_run_services" {
  description = "Cloud Run service URLs"
  value = {
    catalog_products    = google_cloud_run_v2_service.catalog_products.uri
    catalog_categories  = google_cloud_run_v2_service.catalog_categories.uri
    consumer_transactions = google_cloud_run_v2_service.consumer_transactions.uri
    consumer_enrich     = google_cloud_run_v2_service.consumer_enrich.uri
    webapp              = google_cloud_run_v2_service.webapp.uri
  }
}

output "custom_domains" {
  description = "Custom domain mappings"
  value = {
    api    = "api.${var.domain_name}"
    webapp = "app.${var.domain_name}"
  }
}

output "secret_manager_secrets" {
  description = "Secret Manager secret names"
  value = {
    migros_credentials = google_secret_manager_secret.migros_credentials.name
    database_url       = google_secret_manager_secret.database_url.name
    api_keys           = google_secret_manager_secret.api_keys.name
  }
}

output "artifact_registry" {
  description = "Artifact Registry repository details"
  value = {
    repository_id = google_artifact_registry_repository.docker_images.repository_id
    location      = google_artifact_registry_repository.docker_images.location
    repository_url = "${google_artifact_registry_repository.docker_images.location}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.docker_images.repository_id}"
  }
}

output "github_actions_config" {
  description = "GitHub Actions configuration values for repository secrets"
  value = {
    service_account      = google_service_account.github_actions.email
    workload_identity_provider = google_iam_workload_identity_pool_provider.github.name
  }
}
