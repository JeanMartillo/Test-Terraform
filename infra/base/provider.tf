# Setup our GCP provider
variable "region" {
  description = "GCP region for base infrastructure (VPC, Artifact Registry)"
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
    prefix = "base"
    # El bucket del backend se pasa en terraform init:
    # terraform init -backend-config="bucket=mi-bucket-terraform-state"
    #
    # Las credenciales se leen de:
    #  - gcloud auth application-default login
    #  o
    #  - variable de entorno GOOGLE_APPLICATION_CREDENTIALS
  }
}
