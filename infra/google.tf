provider "google" {
  version = "~> 2.13"
  project = "alltheclouds"
  region  = "us-central1"
}

provider "google-beta" {
  version = "~> 2.13"
  project = "alltheclouds"
  region  = "us-central1"
}

resource "google_storage_bucket" "bucket" {
  name = "alltheclouds"
  website {
    main_page_suffix = "index.html"
  }
}

resource "google_storage_bucket_object" "index_page" {
  bucket  = google_storage_bucket.bucket.name
  name    = "index.html"
  content = templatefile("../frontend/index.html", { cloud_provider = "Google Cloud Platform" })
}

resource "google_storage_default_object_acl" "default_object_acl" {
  bucket      = google_storage_bucket.bucket.name
  role_entity = ["READER:allUsers"]
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name       = "alltheclouds"
  target     = google_compute_target_https_proxy.proxy.self_link
  port_range = "443"
}

resource "google_compute_backend_bucket" "backend_bucket" {
  bucket_name = google_storage_bucket.bucket.name
  name        = "alltheclouds"
}

resource "google_compute_ssl_certificate" "certificate" {
  name_prefix = "alltheclouds-"
  private_key = acme_certificate.certificate.private_key_pem
  certificate = acme_certificate.certificate.certificate_pem
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_url_map" "urlmap" {
  name            = "alltheclouds"
  default_service = google_compute_backend_bucket.backend_bucket.self_link
}

resource "google_compute_target_https_proxy" "proxy" {
  name             = "alltheclouds"
  url_map          = google_compute_url_map.urlmap.self_link
  ssl_certificates = [google_compute_ssl_certificate.certificate.self_link]
}