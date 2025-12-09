resource "google_storage_bucket" "news" {
  name                        = "${var.project}-infra-static-pages"
  force_destroy               = true
  location                    = "US"
  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "error.html"
  }
}

# Public read access for static website content.
# NOTE: In production we would likely front this with HTTPS / Cloud CDN
# instead of exposing the bucket directly.
resource "google_storage_bucket_iam_member" "news_public_read" {
  bucket = google_storage_bucket.news.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
