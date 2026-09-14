# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ==============================================================================
# Artifact Registry for Builder Image
# ==============================================================================

resource "google_artifact_registry_repository" "gem" {
  repository_id = var.artifact_registry_repository
  location      = var.ar_location != "" ? var.ar_location : var.region
  format        = "DOCKER"
  description   = "GEM build artifacts (Cloud Build builder image)"
  project       = var.project_id
  depends_on    = [google_project_service.apis]
}

# ==============================================================================
# Secret Manager for SSH Private Key
# ==============================================================================

resource "google_secret_manager_secret" "ssh" {
  secret_id = var.ssh_secret_name
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

# ==============================================================================
# Cloud Build Builder Service Account & Permissions
# ==============================================================================

resource "google_service_account" "builder" {
  account_id   = var.builder_sa_name
  display_name = "GEM Cluster Build SA (Cloud Build)"
  project      = var.project_id
  depends_on   = [google_project_service.apis]
}

resource "google_secret_manager_secret_iam_member" "builder_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.ssh.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.builder.email}"
}

resource "google_project_iam_member" "builder_roles" {
  for_each = toset([
    "roles/storage.objectAdmin",        # Terraform state in GCS
    "roles/iap.tunnelResourceAccessor", # IAP tunnel to workstation + nodes
    "roles/logging.logWriter",          # Custom SA requirement for Cloud Build
    "roles/artifactregistry.writer",    # Build and push the builder image
    "roles/compute.viewer",             # Pre-flight conflict checks on VMs
    "roles/gkehub.viewer",              # Pre-flight conflict checks on fleet
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.builder.email}"
}

resource "google_service_account_iam_member" "builder_impersonates_provisioner" {
  service_account_id = google_service_account.tf_provisioner.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.builder.email}"
}
