# Setup our GCP provider
variable "region" {
  description = "Region where JOI News services will run"
  type        = string
  default     = "us-central1"
}

variable "project" {
  description = "GCP project ID"
  type        = string
}

provider "google" {
  project = var.project
  region  = var.region
}

provider "google-beta" {
  project = var.project
  region  = var.region
}

terraform {
  backend "gcs" {
    prefix = "news"
    # El bucket se pasa en terraform init:
    # terraform init -backend-config="bucket=joi-news-tf-state"
    #
    # Las credenciales vienen de ADC (gcloud o GOOGLE_APPLICATION_CREDENTIALS)
  }
}
