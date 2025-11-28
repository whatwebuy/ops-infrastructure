# Cloud Run Services
# Images will be built and pushed by GitHub Actions CI/CD pipelines

# Catalog Products API
resource "google_cloud_run_v2_service" "catalog_products" {
  name     = "catalog-products"
  location = var.gcp_region
  
  template {
    service_account = google_service_account.catalog_products.email
    
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
    
    containers {
      # Placeholder image - will be updated by CI/CD
      image = "gcr.io/${var.gcp_project_id}/catalog-products:latest"
      
      env {
        name  = "NODE_ENV"
        value = "production"
      }
      
      env {
        name  = "PORT"
        value = "8080"
      }
      
      env {
        name  = "FIRESTORE_PROJECT_ID"
        value = var.gcp_project_id
      }
      
      env {
        name  = "CATALOG_CATEGORIES_URL"
        value = "https://catalog-categories-${data.google_project.project.number}.${var.gcp_region}.run.app"
      }
      
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }
      
      ports {
        container_port = 8080
      }
      
      startup_probe {
        http_get {
          path = "/health"
        }
        initial_delay_seconds = 0
        timeout_seconds       = 1
        period_seconds        = 3
        failure_threshold     = 3
      }
      
      liveness_probe {
        http_get {
          path = "/health"
        }
      }
    }
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  depends_on = [
    google_project_service.required_apis,
    google_firestore_database.main
  ]
  
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }
}

# Catalog Categories API
resource "google_cloud_run_v2_service" "catalog_categories" {
  name     = "catalog-categories"
  location = var.gcp_region
  
  template {
    service_account = google_service_account.catalog_categories.email
    
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
    
    containers {
      image = "gcr.io/${var.gcp_project_id}/catalog-categories:latest"
      
      env {
        name  = "NODE_ENV"
        value = "production"
      }
      
      env {
        name  = "PORT"
        value = "8080"
      }
      
      env {
        name  = "FIRESTORE_PROJECT_ID"
        value = var.gcp_project_id
      }
      
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }
      
      ports {
        container_port = 8080
      }
      
      startup_probe {
        http_get {
          path = "/health"
        }
        initial_delay_seconds = 0
        timeout_seconds       = 1
        period_seconds        = 3
        failure_threshold     = 3
      }
    }
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  depends_on = [
    google_project_service.required_apis,
    google_firestore_database.main
  ]
  
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }
}

# Consumer Transactions API
resource "google_cloud_run_v2_service" "consumer_transactions" {
  name     = "consumer-transactions"
  location = var.gcp_region
  
  template {
    service_account = google_service_account.consumer_transactions.email
    
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
    
    containers {
      image = "gcr.io/${var.gcp_project_id}/consumer-transactions:latest"
      
      env {
        name  = "NODE_ENV"
        value = "production"
      }
      
      env {
        name  = "PORT"
        value = "8080"
      }
      
      env {
        name  = "FIRESTORE_PROJECT_ID"
        value = var.gcp_project_id
      }
      
      env {
        name  = "CATALOG_PRODUCTS_URL"
        value = "https://catalog-products-${data.google_project.project.number}.${var.gcp_region}.run.app"
      }
      
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }
      
      ports {
        container_port = 8080
      }
      
      startup_probe {
        http_get {
          path = "/health"
        }
        initial_delay_seconds = 0
        timeout_seconds       = 1
        period_seconds        = 3
        failure_threshold     = 3
      }
    }
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  depends_on = [
    google_project_service.required_apis,
    google_firestore_database.main
  ]
  
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }
}

# Consumer Enrich Service
resource "google_cloud_run_v2_service" "consumer_enrich" {
  name     = "consumer-enrich"
  location = var.gcp_region
  
  template {
    service_account = google_service_account.consumer_enrich.email
    
    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }
    
    containers {
      image = "gcr.io/${var.gcp_project_id}/consumer-enrich:latest"
      
      env {
        name  = "NODE_ENV"
        value = "production"
      }
      
      env {
        name  = "PORT"
        value = "8080"
      }
      
      env {
        name  = "STORAGE_BUCKET"
        value = google_storage_bucket.files.name
      }
      
      env {
        name  = "CATALOG_PRODUCTS_URL"
        value = "https://catalog-products-${data.google_project.project.number}.${var.gcp_region}.run.app"
      }
      
      env {
        name  = "CATALOG_CATEGORIES_URL"
        value = "https://catalog-categories-${data.google_project.project.number}.${var.gcp_region}.run.app"
      }
      
      env {
        name  = "TRANSACTIONS_API_URL"
        value = "https://consumer-transactions-${data.google_project.project.number}.${var.gcp_region}.run.app"
      }
      
      env {
        name = "MIGROS_EMAIL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.migros_credentials.secret_id
            version = "latest"
          }
        }
      }
      
      env {
        name = "MIGROS_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.migros_password.secret_id
            version = "latest"
          }
        }
      }
      
      resources {
        limits = {
          cpu    = "2"
          memory = "2Gi"
        }
        cpu_idle = false
      }
      
      ports {
        container_port = 8080
      }
      
      startup_probe {
        http_get {
          path = "/health"
        }
        initial_delay_seconds = 0
        timeout_seconds       = 1
        period_seconds        = 3
        failure_threshold     = 3
      }
    }
    
    timeout = "3600s" # 1 hour timeout for long-running enrichment jobs
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  depends_on = [
    google_project_service.required_apis,
    google_storage_bucket.files,
    google_secret_manager_secret_version.migros_credentials,
    google_secret_manager_secret_version.migros_password
  ]
  
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }
}

# Consumer Webapp
resource "google_cloud_run_v2_service" "webapp" {
  name     = "consumer-webapp"
  location = var.gcp_region
  
  template {
    service_account = google_service_account.webapp.email
    
    scaling {
      min_instance_count = 0
      max_instance_count = 20
    }
    
    containers {
      image = "gcr.io/${var.gcp_project_id}/consumer-webapp:latest"
      
      env {
        name  = "VITE_API_BASE_URL"
        value = "https://api.${var.domain_name}"
      }
      
      resources {
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }
        cpu_idle = true
      }
      
      ports {
        container_port = 80
      }
      
      startup_probe {
        http_get {
          path = "/"
        }
        initial_delay_seconds = 0
        timeout_seconds       = 1
        period_seconds        = 3
        failure_threshold     = 3
      }
    }
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  depends_on = [
    google_project_service.required_apis
  ]
  
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }
}

# IAM policy to allow public access to webapp
resource "google_cloud_run_v2_service_iam_member" "webapp_public" {
  name     = google_cloud_run_v2_service.webapp.name
  location = google_cloud_run_v2_service.webapp.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# IAM policy for authenticated API access (add specific users/service accounts as needed)
resource "google_cloud_run_v2_service_iam_member" "api_invokers" {
  for_each = toset([
    google_cloud_run_v2_service.catalog_products.name,
    google_cloud_run_v2_service.catalog_categories.name,
    google_cloud_run_v2_service.consumer_transactions.name,
  ])
  
  name     = each.value
  location = var.gcp_region
  role     = "roles/run.invoker"
  member   = "allUsers" # Change to specific service accounts in production
}

# Allow enrich service to be invoked
resource "google_cloud_run_v2_service_iam_member" "enrich_invoker" {
  name     = google_cloud_run_v2_service.consumer_enrich.name
  location = google_cloud_run_v2_service.consumer_enrich.location
  role     = "roles/run.invoker"
  member   = "allUsers" # Restrict this in production
}

# Data source for project number
data "google_project" "project" {
  project_id = var.gcp_project_id
}
