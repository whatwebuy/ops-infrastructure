# Service Accounts for Cloud Run services

# Catalog Products API Service Account
resource "google_service_account" "catalog_products" {
  account_id   = "catalog-products-sa"
  display_name = "Catalog Products API Service Account"
  description  = "Service account for catalog-products Cloud Run service"
}

# Catalog Categories API Service Account
resource "google_service_account" "catalog_categories" {
  account_id   = "catalog-categories-sa"
  display_name = "Catalog Categories API Service Account"
  description  = "Service account for catalog-categories Cloud Run service"
}

# Consumer Transactions API Service Account
resource "google_service_account" "consumer_transactions" {
  account_id   = "consumer-transactions-sa"
  display_name = "Consumer Transactions API Service Account"
  description  = "Service account for consumer-history-transactions Cloud Run service"
}

# Consumer Enrich Service Account
resource "google_service_account" "consumer_enrich" {
  account_id   = "consumer-enrich-sa"
  display_name = "Consumer Enrich Service Account"
  description  = "Service account for consumer-enrich-history-migros Cloud Run service"
}

# Webapp Service Account
resource "google_service_account" "webapp" {
  account_id   = "webapp-sa"
  display_name = "Consumer Webapp Service Account"
  description  = "Service account for consumer-webapp Cloud Run service"
}

# Grant Firestore access to all service accounts
resource "google_project_iam_member" "firestore_user" {
  for_each = toset([
    google_service_account.catalog_products.email,
    google_service_account.catalog_categories.email,
    google_service_account.consumer_transactions.email,
    google_service_account.consumer_enrich.email,
  ])
  
  project = var.gcp_project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${each.value}"
}

# Grant Secret Manager access to services that need it
resource "google_project_iam_member" "secret_accessor" {
  for_each = toset([
    google_service_account.consumer_enrich.email,
    google_service_account.consumer_transactions.email,
  ])
  
  project = var.gcp_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${each.value}"
}
