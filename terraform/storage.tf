# Cloud Storage Bucket for CSV/PDF files from enrichment pipeline
resource "google_storage_bucket" "files" {
  name          = "${var.gcp_project_id}-whatwebuy-files"
  location      = var.gcp_region
  storage_class = "STANDARD"
  
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
  
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }
  
  cors {
    origin          = ["https://${var.domain_name}", "https://app.${var.domain_name}"]
    method          = ["GET", "HEAD", "PUT", "POST"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
  
  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "receipts-storage"
  }
  
  depends_on = [
    google_project_service.required_apis
  ]
}

# Bucket for Terraform state (must be created manually first)
# This is referenced in main.tf backend configuration
# To create manually:
# gsutil mb -p <project-id> -l <region> gs://whatwebuy-terraform-state
# gsutil versioning set on gs://whatwebuy-terraform-state

# Folders structure in the files bucket (logical organization)
resource "google_storage_bucket_object" "receipts_folder" {
  name    = "receipts/"
  content = "Receipts folder"
  bucket  = google_storage_bucket.files.name
}

resource "google_storage_bucket_object" "csv_folder" {
  name    = "receipts/csv/"
  content = "CSV receipts folder"
  bucket  = google_storage_bucket.files.name
}

resource "google_storage_bucket_object" "pdf_folder" {
  name    = "receipts/pdf/"
  content = "PDF receipts folder"
  bucket  = google_storage_bucket.files.name
}

resource "google_storage_bucket_object" "exports_folder" {
  name    = "exports/"
  content = "Exports folder"
  bucket  = google_storage_bucket.files.name
}

# IAM binding for Cloud Run services to access the bucket
resource "google_storage_bucket_iam_member" "enrich_service_access" {
  bucket = google_storage_bucket.files.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.consumer_enrich.email}"
}

resource "google_storage_bucket_iam_member" "transactions_service_read" {
  bucket = google_storage_bucket.files.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.consumer_transactions.email}"
}
