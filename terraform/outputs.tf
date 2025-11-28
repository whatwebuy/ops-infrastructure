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
