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

data "google_project" "project" {
  project_id = var.project_id
}

# ==============================================================================
# VPC Network & Subnets
# ==============================================================================

resource "google_compute_network" "gdc_vpc" {
  name                    = var.gce_network
  project                 = var.project_id
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "gdc_subnet" {
  name          = var.gce_subnetwork
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.gdc_vpc.self_link
  ip_cidr_range = var.gce_subnetwork_cidr
}

# ==============================================================================
# Firewall Rules
# ==============================================================================

resource "google_compute_firewall" "gdc_allow_internal" {
  name    = "gem-clusters-allow-internal"
  project = var.project_id
  network = google_compute_network.gdc_vpc.self_link

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.gce_subnetwork_cidr]
  target_tags   = ["http-server", "https-server"]
}

resource "google_compute_firewall" "gdc_allow_ssh" {
  name    = "gem-clusters-allow-iap-ssh"
  project = var.project_id
  network = google_compute_network.gdc_vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"] # IAP Range
  target_tags   = ["http-server", "https-server"]
}

# ==============================================================================
# Cloud Router & NAT
# ==============================================================================

resource "google_compute_router" "router" {
  name    = "${var.gce_network}-router"
  region  = var.region
  network = google_compute_network.gdc_vpc.self_link
  project = var.project_id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.gce_network}-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# ==============================================================================
# VXLAN Overlay Synchronization Storage Bucket
# ==============================================================================

resource "google_storage_bucket" "overlay_sync" {
  name                        = "gem-${var.project_id}-overlay-sync"
  location                    = var.region
  project                     = var.project_id
  force_destroy               = true
  uniform_bucket_level_access = true
  depends_on                  = [google_project_service.apis]
}

resource "google_storage_bucket_iam_member" "overlay_sync_accessor" {
  bucket     = google_storage_bucket.overlay_sync.name
  role       = "roles/storage.objectAdmin"
  member     = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
  depends_on = [google_project_service.apis]
}

# ==============================================================================
# Service Accounts for Anthos & Fleet Management
# ==============================================================================

resource "google_service_account" "baremetal_gcr" {
  account_id   = "baremetal-gcr"
  display_name = "Service Account for Anthos Bare Metal"
  project      = var.project_id
  depends_on   = [google_project_service.apis]
}

resource "google_project_iam_member" "baremetal_gcr_roles" {
  for_each = toset([
    "roles/gkehub.connect",
    "roles/gkehub.admin",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.dashboardEditor",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/opsconfigmonitoring.resourceMetadata.writer",
    "roles/kubernetesmetadata.publisher",
    "roles/compute.viewer",
    "roles/serviceusage.serviceUsageViewer"
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.baremetal_gcr.email}"
}

resource "google_service_account" "gem_cluster_admin" {
  account_id   = "gem-cluster-admin"
  display_name = "GEM Cluster Admin"
  project      = var.project_id
  depends_on   = [google_project_service.apis]
}

resource "google_project_iam_member" "gem_cluster_admin_roles" {
  for_each = toset([
    "roles/gkehub.gatewayAdmin",
    "roles/gkehub.admin"
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gem_cluster_admin.email}"
}

# ==============================================================================
# GKE Hub Features
# ==============================================================================

resource "google_gke_hub_feature" "configmanagement" {
  name       = "configmanagement"
  location   = "global"
  project    = var.project_id
  depends_on = [google_project_service.apis]
}
