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

output "project_id" {
  description = "Target Google Cloud Project ID"
  value       = var.project_id
}

output "project_number" {
  description = "Numeric Project Number"
  value       = data.google_project.project.number
}

output "region" {
  description = "Configured GCP Region"
  value       = var.region
}

output "zone" {
  description = "Configured GCP Zone"
  value       = var.zone
}

output "network_name" {
  description = "Name of the VPC Network"
  value       = google_compute_network.gdc_vpc.name
}

output "subnetwork_name" {
  description = "Name of the Subnetwork"
  value       = google_compute_subnetwork.gdc_subnet.name
}

output "workstation_name" {
  description = "Name of the Admin Workstation GCE instance"
  value       = google_compute_instance.admin_ws.name
}

output "workstation_ip" {
  description = "Internal IP of the Admin Workstation GCE instance"
  value       = google_compute_instance.admin_ws.network_interface[0].network_ip
}

output "edge_router_name" {
  description = "Name of the Edge Router GCE instance"
  value       = google_compute_instance.edge_router.name
}

output "edge_router_ip" {
  description = "Internal IP of the Edge Router GCE instance"
  value       = google_compute_instance.edge_router.network_interface[0].network_ip
}

output "anthos_sa_email" {
  description = "Email of the Anthos Baremetal GCR Service Account"
  value       = google_service_account.baremetal_gcr.email
}

output "gem_cluster_admin_sa_email" {
  description = "Email of the GEM Cluster Admin Service Account"
  value       = google_service_account.gem_cluster_admin.email
}

output "overlay_sync_bucket_name" {
  description = "GCS bucket used to synchronize VXLAN overlay configurations"
  value       = google_storage_bucket.overlay_sync.name
}

output "state_bucket_name" {
  description = "Remote Terraform state bucket name"
  value       = google_storage_bucket.tf_state.name
}

output "state_bucket_url" {
  description = "Remote Terraform state bucket URL"
  value       = google_storage_bucket.tf_state.url
}

output "wif_pool_id" {
  description = "Workload Identity Pool ID"
  value       = google_iam_workload_identity_pool.gh_actions_pool.workload_identity_pool_id
}

output "wif_pool_name" {
  description = "Workload Identity Pool Resource Name"
  value       = google_iam_workload_identity_pool.gh_actions_pool.name
}

output "wif_provider_id" {
  description = "Workload Identity Provider ID"
  value       = google_iam_workload_identity_pool_provider.github_provider.workload_identity_pool_provider_id
}

output "wif_provider_name" {
  description = "Workload Identity Provider Resource Name"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "tf_provisioner_sa_email" {
  description = "Terraform Provisioner Service Account Email"
  value       = google_service_account.tf_provisioner.email
}

output "tf_provisioner_sa_name" {
  description = "Terraform Provisioner Service Account Resource Name"
  value       = google_service_account.tf_provisioner.name
}

output "builder_sa_email" {
  description = "Cloud Build builder service account email"
  value       = google_service_account.builder.email
}

output "ssh_secret_name" {
  description = "Secret Manager secret name holding the SSH private key"
  value       = google_secret_manager_secret.ssh.secret_id
}

output "ssh_secret_id" {
  description = "Fully qualified Secret Manager secret ID"
  value       = google_secret_manager_secret.ssh.id
}

output "artifact_registry_repo" {
  description = "Artifact Registry Docker repository URI"
  value       = "${google_artifact_registry_repository.gem.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.gem.repository_id}"
}

output "artifact_registry_location" {
  description = "Artifact Registry location"
  value       = google_artifact_registry_repository.gem.location
}
