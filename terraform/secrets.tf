# Secret Manager - Store sensitive credentials

# Migros credentials for enrichment service
resource "google_secret_manager_secret" "migros_credentials" {
  secret_id = "migros-email"
  
  replication {
    auto {}
  }
  
  labels = {
    environment = var.environment
    service     = "consumer-enrich"
  }
  
  depends_on = [
    google_project_service.required_apis
  ]
}

resource "google_secret_manager_secret" "migros_password" {
  secret_id = "migros-password"
  
  replication {
    auto {}
  }
  
  labels = {
    environment = var.environment
    service     = "consumer-enrich"
  }
  
  depends_on = [
    google_project_service.required_apis
  ]
}

# Database connection URL (for future use if moving to Cloud SQL)
resource "google_secret_manager_secret" "database_url" {
  secret_id = "database-url"
  
  replication {
    auto {}
  }
  
  labels = {
    environment = var.environment
    service     = "all"
  }
  
  depends_on = [
    google_project_service.required_apis
  ]
}

# API keys for external services
resource "google_secret_manager_secret" "api_keys" {
  secret_id = "api-keys"
  
  replication {
    auto {}
  }
  
  labels = {
    environment = var.environment
    service     = "all"
  }
  
  depends_on = [
    google_project_service.required_apis
  ]
}

# Placeholder secret versions (must be updated manually after creation)
resource "google_secret_manager_secret_version" "migros_credentials" {
  secret      = google_secret_manager_secret.migros_credentials.id
  secret_data = "your-migros-email@example.com" # Update via gcloud or console
  
  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_version" "migros_password" {
  secret      = google_secret_manager_secret.migros_password.id
  secret_data = "changeme" # Update via gcloud or console
  
  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.database_url.id
  secret_data = "firestore://${var.gcp_project_id}"
  
  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_version" "api_keys" {
  secret      = google_secret_manager_secret.api_keys.id
  secret_data = "{}"
  
  lifecycle {
    ignore_changes = [secret_data]
  }
}

# IAM bindings for secret access
resource "google_secret_manager_secret_iam_member" "enrich_migros_email" {
  secret_id = google_secret_manager_secret.migros_credentials.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.consumer_enrich.email}"
}

resource "google_secret_manager_secret_iam_member" "enrich_migros_password" {
  secret_id = google_secret_manager_secret.migros_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.consumer_enrich.email}"
}

resource "google_secret_manager_secret_iam_member" "services_database_url" {
  for_each = tomap({
    catalog_products      = google_service_account.catalog_products.email
    catalog_categories    = google_service_account.catalog_categories.email
    consumer_transactions = google_service_account.consumer_transactions.email
    consumer_enrich       = google_service_account.consumer_enrich.email
  })

  secret_id = google_secret_manager_secret.database_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value}"
}
