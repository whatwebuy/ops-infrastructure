variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "europe-west6"
}

variable "environment" {
  description = "Environment name (production, staging)"
  type        = string
  default     = "production"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "whatwebuy.ai"
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repos" {
  description = "GitHub repository names"
  type = object({
    catalog_api  = string
    consumer_api = string
    webapp       = string
  })
  default = {
    catalog_api  = "catalog-api"
    consumer_api = "consumer-api"
    webapp       = "consumer-webapp"
  }
}
