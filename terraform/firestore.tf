# Firestore Database - Shared by all services
resource "google_firestore_database" "main" {
  project     = var.gcp_project_id
  name        = "(default)"
  location_id = var.gcp_region
  type        = "FIRESTORE_NATIVE"
  
  # Prevents accidental deletion
  deletion_policy = "DELETE"
  
  depends_on = [
    google_project_service.required_apis
  ]
}

# Firestore indexes for efficient queries
resource "google_firestore_index" "transactions_by_date" {
  project    = var.gcp_project_id
  database   = google_firestore_database.main.name
  collection = "transactions"
  
  fields {
    field_path = "timestamp"
    order      = "DESCENDING"
  }
  
  fields {
    field_path = "store_type"
    order      = "ASCENDING"
  }
  
  fields {
    field_path = "__name__"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "transactions_by_store" {
  project    = var.gcp_project_id
  database   = google_firestore_database.main.name
  collection = "transactions"
  
  fields {
    field_path = "store_name"
    order      = "ASCENDING"
  }
  
  fields {
    field_path = "timestamp"
    order      = "DESCENDING"
  }
  
  fields {
    field_path = "__name__"
    order      = "DESCENDING"
  }
}

resource "google_firestore_index" "products_by_category" {
  project    = var.gcp_project_id
  database   = google_firestore_database.main.name
  collection = "products"

  fields {
    field_path = "categoryId"
    order      = "ASCENDING"
  }

  fields {
    field_path = "lastSeen"
    order      = "DESCENDING"
  }

  fields {
    field_path = "__name__"
    order      = "DESCENDING"
  }
}

# Single field index not needed - Firestore handles this automatically
# resource "google_firestore_index" "categories_search" {
#   project    = var.gcp_project_id
#   database   = google_firestore_database.main.name
#   collection = "categories"
#
#   fields {
#     field_path = "name_de"
#     order      = "ASCENDING"
#   }
#
#   fields {
#     field_path = "__name__"
#     order      = "ASCENDING"
#   }
# }
