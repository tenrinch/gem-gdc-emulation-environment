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

locals {
  state_bucket_name = var.state_bucket_name != "" ? var.state_bucket_name : "${var.project_id}-state"

  wif_principal_set = var.github_repo != "" ? "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.gh_actions_pool.name}/attribute.repository/${var.github_org}/${var.github_repo}" : "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.gh_actions_pool.name}/attribute.repository_owner/${var.github_org}"

  tf_provisioner_roles = [
    "roles/compute.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountKeyAdmin",
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountTokenCreator",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/secretmanager.admin",
    "roles/artifactregistry.admin",
    "roles/gkehub.admin",
    "roles/storage.admin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/iap.tunnelResourceAccessor",
    "roles/cloudbuild.builds.editor"
  ]
}

# ==============================================================================
# Declarative GCP API Services Enablement
# ==============================================================================

resource "google_project_service" "apis" {
  for_each                   = toset(var.activate_apis)
  project                    = var.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}

# ==============================================================================
# Hardened Remote State GCS Storage Bucket
# ==============================================================================

resource "google_storage_bucket" "tf_state" {
  name                        = local.state_bucket_name
  project                     = var.project_id
  location                    = var.state_bucket_location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.state_bucket_force_destroy

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      days_since_noncurrent_time = var.state_retention_days
    }
  }

  lifecycle_rule {
    action {
      type = "AbortIncompleteMultipartUpload"
    }
    condition {
      age = 7
    }
  }

  labels = var.labels

  depends_on = [google_project_service.apis]
}

# ==============================================================================
# Workload Identity Federation (WIF) Pool & OIDC Provider
# ==============================================================================

resource "google_iam_workload_identity_pool" "gh_actions_pool" {
  project                   = var.project_id
  workload_identity_pool_id = var.wif_pool_id
  display_name              = "GitHub Actions WIF Pool"
  description               = "Workload Identity Pool for GitHub Actions keyless CI/CD authentication"
  disabled                  = false

  lifecycle {
    ignore_changes = [project]
  }

  depends_on = [
    google_project_service.apis
  ]
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.gh_actions_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.wif_provider_id
  display_name                       = "GitHub Actions Provider"
  description                        = "OIDC Identity Provider for GitHub Actions"
  disabled                           = false

  lifecycle {
    ignore_changes = [project]
  }

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.aud"              = "assertion.aud"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_condition = var.github_repo != "" ? "assertion.repository == '${var.github_org}/${var.github_repo}'" : "assertion.repository_owner == '${var.github_org}'"

  depends_on = [
    google_iam_workload_identity_pool.gh_actions_pool
  ]
}

# ==============================================================================
# Least-Privilege Terraform Provisioner Service Account
# ==============================================================================

resource "google_service_account" "tf_provisioner" {
  project      = var.project_id
  account_id   = "tf-provisioner"
  display_name = "Terraform Provisioner Service Account"
  description  = "Dedicated service account for Terraform infrastructure deployment across all layers"

  depends_on = [google_project_service.apis]
}

# ==============================================================================
# Provisioner IAM Role Assignments
# ==============================================================================

resource "google_project_iam_member" "tf_provisioner_roles" {
  for_each = toset(local.tf_provisioner_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.tf_provisioner.email}"
}

# ==============================================================================
# Workload Identity Federation Impersonation Bindings
# ==============================================================================

resource "google_service_account_iam_member" "wif_impersonation" {
  count = var.github_org != "" ? 1 : 0

  service_account_id = google_service_account.tf_provisioner.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.wif_principal_set

  depends_on = [
    google_iam_workload_identity_pool_provider.github_provider
  ]
}

# ==============================================================================
# Local Human Operator Impersonation Bindings
# ==============================================================================

resource "google_service_account_iam_member" "operator_token_creator" {
  count = var.operator_user_email != "" ? 1 : 0

  service_account_id = google_service_account.tf_provisioner.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${var.operator_user_email}"
}

# ==============================================================================
# Local State & Inventory Synchronization Object
# ==============================================================================
# Synchronizes the bootstrap outputs directly into the local state bucket so that
# ansible/inventory.sh and Cloud Build can discover the workstation and router
# endpoints with zero drift, regardless of where the root Terraform state is stored.
resource "google_storage_bucket_object" "inventory_state" {
  name   = "bootstrap/state/default.tfstate"
  bucket = google_storage_bucket.tf_state.name

  content = jsonencode({
    version           = 4
    terraform_version = "1.12.2"
    serial            = 1
    outputs = {
      workstation_name = {
        value = google_compute_instance.admin_ws.name
        type  = "string"
      }
      workstation_ip = {
        value = google_compute_instance.admin_ws.network_interface[0].network_ip
        type  = "string"
      }
      edge_router_name = {
        value = google_compute_instance.edge_router.name
        type  = "string"
      }
      edge_router_ip = {
        value = google_compute_instance.edge_router.network_interface[0].network_ip
        type  = "string"
      }
      project_id = {
        value = var.project_id
        type  = "string"
      }
      project_number = {
        value = tostring(data.google_project.project.number)
        type  = "string"
      }
      zone = {
        value = var.zone
        type  = "string"
      }
      region = {
        value = var.region
        type  = "string"
      }
    }
  })

  depends_on = [
    google_compute_instance.admin_ws,
    google_compute_instance.edge_router,
  ]
}



