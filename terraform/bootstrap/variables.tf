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

variable "project_id" {
  type        = string
  description = "The target Google Cloud Project ID"
}

variable "region" {
  type        = string
  description = "The primary Google Cloud region for foundation and cluster resources"
}

variable "zone" {
  type        = string
  description = "The primary Google Cloud compute zone"
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection on Compute Engine instances (set false for non-prod, true for prod)"
  default     = true
}

variable "gce_network" {
  type        = string
  description = "Name of the VPC network"
  default     = "gem-clusters-vpc"
}

variable "gce_subnetwork" {
  type        = string
  description = "Name of the subnet"
  default     = "gem-clusters-subnet"
}

variable "gce_subnetwork_cidr" {
  type        = string
  description = "CIDR range for the VPC subnetwork"
  default     = "10.10.0.0/24"
}

variable "state_bucket_name" {
  type        = string
  description = "Name of the GCS bucket for remote Terraform state storage. Defaults to <project_id>-state."
  default     = ""
}

variable "state_bucket_location" {
  type        = string
  description = "Location for the Terraform state storage bucket"
  default     = "US"
}

variable "state_bucket_force_destroy" {
  type        = bool
  description = "Allow deletion of state bucket even if it contains objects"
  default     = true
}

variable "state_retention_days" {
  type        = number
  description = "Number of days before non-current state file versions are purged"
  default     = 30
}

variable "github_org" {
  type        = string
  description = "GitHub organization or user owning the repository for Workload Identity Federation"
  default     = ""
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name allowed to authenticate via Workload Identity Federation"
  default     = ""
}

variable "wif_pool_id" {
  type        = string
  description = "ID for the Workload Identity Pool"
  default     = "gh-actions-pool"
}

variable "wif_provider_id" {
  type        = string
  description = "ID for the Workload Identity Provider"
  default     = "github-provider"
}

variable "operator_user_email" {
  type        = string
  description = "Optional user email to grant TokenCreator permissions on the Terraform provisioner SA"
  default     = ""
}

variable "admin_ws_machine_type" {
  type        = string
  description = "Compute instance machine type for the Admin Workstation"
  default     = "e2-standard-4"
}

variable "edge_router_name" {
  type        = string
  description = "Name of the Edge Router instance"
  default     = "gem-edge-router"
}

variable "edge_router_machine_type" {
  type        = string
  description = "Compute instance machine type for the Edge Router"
  default     = "e2-small"
}

variable "builder_sa_name" {
  type        = string
  description = "Name of the Service Account used by Cloud Build"
  default     = "gem-cluster-builder"
}

variable "artifact_registry_repository" {
  type        = string
  description = "Artifact Registry repository name for Cloud Build images"
  default     = "gem"
}

variable "ar_location" {
  type        = string
  description = "Artifact Registry repository location. Defaults to var.region if empty."
  default     = ""
}

variable "ssh_secret_name" {
  type        = string
  description = "Secret Manager secret name holding the workstation/cluster SSH private key"
  default     = "gem-cluster-builder-ssh-key"
}

variable "activate_apis" {
  type        = list(string)
  description = "List of GCP service APIs to activate"
  default = [
    "anthos.googleapis.com",
    "anthosaudit.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
    "anthosgke.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "connectgateway.googleapis.com",
    "container.googleapis.com",
    "gkeconnect.googleapis.com",
    "gkehub.googleapis.com",
    "gkeonprem.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "iap.googleapis.com",
    "kubernetesmetadata.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "networkmanagement.googleapis.com",
    "opsconfigmonitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "serviceusage.googleapis.com",
    "stackdriver.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com"
  ]
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to supported resources"
  default     = {}
}
