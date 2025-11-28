# DNS and SSL Configuration for whatwebuy.ai domain
# Note: Domain must be registered and DNS managed through GoDaddy or Cloud DNS

# Global Load Balancer components for custom domain mapping

# Reserve global IP addresses
resource "google_compute_global_address" "api" {
  name = "whatwebuy-api-ip"
}

resource "google_compute_global_address" "webapp" {
  name = "whatwebuy-webapp-ip"
}

# SSL Certificate for API subdomain
resource "google_compute_managed_ssl_certificate" "api" {
  name = "whatwebuy-api-ssl"
  
  managed {
    domains = [
      "api.${var.domain_name}",
    ]
  }
}

# SSL Certificate for Webapp subdomain
resource "google_compute_managed_ssl_certificate" "webapp" {
  name = "whatwebuy-webapp-ssl"
  
  managed {
    domains = [
      "app.${var.domain_name}",
      var.domain_name,
    ]
  }
}

# Network Endpoint Group for API services
resource "google_compute_region_network_endpoint_group" "api_neg" {
  name                  = "api-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.gcp_region
  
  cloud_run {
    service = google_cloud_run_v2_service.consumer_transactions.name
  }
}

# Network Endpoint Group for Webapp
resource "google_compute_region_network_endpoint_group" "webapp_neg" {
  name                  = "webapp-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.gcp_region
  
  cloud_run {
    service = google_cloud_run_v2_service.webapp.name
  }
}

# Backend service for API
resource "google_compute_backend_service" "api" {
  name                  = "api-backend"
  protocol              = "HTTPS"
  port_name             = "http"
  timeout_sec           = 30
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.api_neg.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# Backend service for Webapp
resource "google_compute_backend_service" "webapp" {
  name                  = "webapp-backend"
  protocol              = "HTTPS"
  port_name             = "http"
  timeout_sec           = 30
  enable_cdn            = true
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.webapp_neg.id
  }

  cdn_policy {
    cache_mode        = "CACHE_ALL_STATIC"
    default_ttl       = 3600
    max_ttl           = 86400
    client_ttl        = 3600
    negative_caching  = true

    cache_key_policy {
      include_host         = true
      include_protocol     = true
      include_query_string = false
    }
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL Map for API
resource "google_compute_url_map" "api" {
  name            = "api-url-map"
  default_service = google_compute_backend_service.api.id
}

# URL Map for Webapp
resource "google_compute_url_map" "webapp" {
  name            = "webapp-url-map"
  default_service = google_compute_backend_service.webapp.id
}

# HTTPS Proxy for API
resource "google_compute_target_https_proxy" "api" {
  name             = "api-https-proxy"
  url_map          = google_compute_url_map.api.id
  ssl_certificates = [google_compute_managed_ssl_certificate.api.id]
}

# HTTPS Proxy for Webapp
resource "google_compute_target_https_proxy" "webapp" {
  name             = "webapp-https-proxy"
  url_map          = google_compute_url_map.webapp.id
  ssl_certificates = [google_compute_managed_ssl_certificate.webapp.id]
}

# Forwarding rule for API
resource "google_compute_global_forwarding_rule" "api" {
  name                  = "api-forwarding-rule"
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.api.id
  ip_address            = google_compute_global_address.api.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# Forwarding rule for Webapp
resource "google_compute_global_forwarding_rule" "webapp" {
  name                  = "webapp-forwarding-rule"
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.webapp.id
  ip_address            = google_compute_global_address.webapp.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# HTTP to HTTPS redirect for API
resource "google_compute_url_map" "api_http_redirect" {
  name = "api-http-redirect"
  
  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "api_http" {
  name    = "api-http-proxy"
  url_map = google_compute_url_map.api_http_redirect.id
}

resource "google_compute_global_forwarding_rule" "api_http" {
  name                  = "api-http-forwarding-rule"
  ip_protocol           = "TCP"
  port_range            = "80"
  target                = google_compute_target_http_proxy.api_http.id
  ip_address            = google_compute_global_address.api.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# HTTP to HTTPS redirect for Webapp
resource "google_compute_url_map" "webapp_http_redirect" {
  name = "webapp-http-redirect"
  
  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "webapp_http" {
  name    = "webapp-http-proxy"
  url_map = google_compute_url_map.webapp_http_redirect.id
}

resource "google_compute_global_forwarding_rule" "webapp_http" {
  name                  = "webapp-http-forwarding-rule"
  ip_protocol           = "TCP"
  port_range            = "80"
  target                = google_compute_target_http_proxy.webapp_http.id
  ip_address            = google_compute_global_address.webapp.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# GoDaddy DNS Records - Automatically configured via API
resource "godaddy_domain_record" "api" {
  domain = var.domain_name

  record {
    name = "api"
    type = "A"
    data = google_compute_global_address.api.address
    ttl  = 600
  }
}

resource "godaddy_domain_record" "app" {
  domain = var.domain_name

  record {
    name = "app"
    type = "A"
    data = google_compute_global_address.webapp.address
    ttl  = 600
  }
}

resource "godaddy_domain_record" "root" {
  domain = var.domain_name

  record {
    name = "@"
    type = "A"
    data = google_compute_global_address.webapp.address
    ttl  = 600
  }
}

# Outputs for DNS configuration verification
output "dns_records" {
  description = "DNS records configured in GoDaddy"
  value = {
    api_a_record = {
      name  = "api"
      type  = "A"
      value = google_compute_global_address.api.address
      ttl   = 600
    }
    webapp_a_record = {
      name  = "app"
      type  = "A"
      value = google_compute_global_address.webapp.address
      ttl   = 600
    }
    root_a_record = {
      name  = "@"
      type  = "A"
      value = google_compute_global_address.webapp.address
      ttl   = 600
    }
  }
}
