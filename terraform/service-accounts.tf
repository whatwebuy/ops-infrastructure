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
  for_each = tomap({
    catalog_products      = google_service_account.catalog_products.email
    catalog_categories    = google_service_account.catalog_categories.email
    consumer_transactions = google_service_account.consumer_transactions.email
    consumer_enrich       = google_service_account.consumer_enrich.email
  })

  project = var.gcp_project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${each.value}"
}

# Grant Secret Manager access to services that need it
resource "google_project_iam_member" "secret_accessor" {
  for_each = tomap({
    consumer_enrich       = google_service_account.consumer_enrich.email
    consumer_transactions = google_service_account.consumer_transactions.email
  })

  project = var.gcp_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${each.value}"
}

# GitHub Actions Service Account for CI/CD
resource "google_service_account" "github_actions" {
  account_id   = "github-actions"
  display_name = "GitHub Actions CI/CD Service Account"
  description  = "Service account for GitHub Actions workflows to deploy services"
}

# Grant GitHub Actions SA permissions to deploy to Cloud Run
resource "google_project_iam_member" "github_actions_run_admin" {
  project = var.gcp_project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Grant GitHub Actions SA permissions to act as Cloud Run service accounts
resource "google_service_account_iam_member" "github_actions_service_account_user" {
  for_each = tomap({
    catalog_products      = google_service_account.catalog_products.name
    catalog_categories    = google_service_account.catalog_categories.name
    consumer_transactions = google_service_account.consumer_transactions.name
    consumer_enrich       = google_service_account.consumer_enrich.name
    webapp                = google_service_account.webapp.name
  })

  service_account_id = each.value
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_actions.email}"
}

# Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github_actions" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions"
}

# Workload Identity Provider for GitHub
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"
  description                        = "OIDC provider for GitHub Actions"

  attribute_condition = "assertion.repository_owner == 'whatwebuy'"

  attribute_mapping = {
    "google.subject"              = "assertion.sub"
    "attribute.actor"             = "assertion.actor"
    "attribute.repository"        = "assertion.repository"
    "attribute.repository_owner"  = "assertion.repository_owner"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Allow GitHub Actions from specific repos to use the service account
resource "google_service_account_iam_member" "github_workload_identity" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/${var.github_org}/${var.github_repos.catalog_api}"
}

resource "google_service_account_iam_member" "github_workload_identity_consumer_api" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/${var.github_org}/${var.github_repos.consumer_api}"
}

resource "google_service_account_iam_member" "github_workload_identity_webapp" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/${var.github_org}/${var.github_repos.webapp}"
}

resource "google_service_account_iam_member" "github_workload_identity_ops" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/${var.github_org}/ops-infrastructure"
}
