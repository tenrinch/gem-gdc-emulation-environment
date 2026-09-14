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

terraform {
  required_version = ">= 1.12.2"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.30.0"
    }
  }
}

provider "google" {
  project                     = var.project_id
  region                      = var.region
  zone                        = var.zone
  impersonate_service_account = var.provisioning_sa_email
}

# ==============================================================================
# Foundation & Workstation Data Lookups
# ==============================================================================

data "google_compute_network" "gdc_vpc" {
  name    = var.gce_network
  project = var.project_id
}

data "google_compute_subnetwork" "gdc_subnet" {
  name    = var.gce_subnetwork
  region  = var.region
  project = var.project_id
}

data "google_compute_instance" "gem_admin_ws" {
  name    = "gem-admin-ws"
  zone    = var.zone
  project = var.project_id
}

data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}

# ==============================================================================
# Hardware Variant Specifications & Node Topology
# ==============================================================================

locals {
  vms = {
    node1 = "${var.cluster_name}-1"
    node2 = "${var.cluster_name}-2"
    node3 = "${var.cluster_name}-3"
  }

  # Mappings for official GDC connected hardware offerings to GCE resources
  hardware_variants = {
    # G1 Hardware Variants
    g1-medium = {
      machine_type   = "n2-custom-32-65536" # 32 vCPU, 64GB RAM
      cpu_platform   = "Intel Ice Lake"
      data_disk_size = 1600 # 1.6 TB SSD
      boot_disk_size = 100
      boot_disk_type = "pd-ssd"
      data_disk_type = "pd-ssd"
    }
    g1-large = {
      machine_type   = "n2-custom-64-131072" # 64 vCPU, 128 GB RAM
      cpu_platform   = "Intel Ice Lake"
      data_disk_size = 3200 # 3.2 TB SSD
      boot_disk_size = 100
      boot_disk_type = "pd-ssd"
      data_disk_type = "pd-ssd"
    }

    # G2 Hardware Variants
    g2-small-64gb = {
      machine_type   = "n4-custom-32-65536" # 32 vCPU, 64 GB RAM
      cpu_platform   = "Intel Emerald Rapids"
      data_disk_size = 3840 # 3.84 TB SSD
      boot_disk_size = 100
      boot_disk_type = "hyperdisk-balanced"
      data_disk_type = "hyperdisk-balanced"
    }
    g2-small-128gb = {
      machine_type   = "n4-standard-32" # 32 vCPU, 128 GB RAM
      cpu_platform   = "Intel Emerald Rapids"
      data_disk_size = 3840 # 3.84 TB SSD
      boot_disk_size = 100
      boot_disk_type = "hyperdisk-balanced"
      data_disk_type = "hyperdisk-balanced"
    }
    g2-medium = {
      machine_type   = "n4-custom-48-131072" # 48 vCPU, 128 GB RAM
      cpu_platform   = "Intel Emerald Rapids"
      data_disk_size = 3840 # 3.84 TB SSD
      boot_disk_size = 100
      boot_disk_type = "hyperdisk-balanced"
      data_disk_type = "hyperdisk-balanced"
    }
    g2-large = {
      machine_type   = "n4-custom-64-131072" # 64 vCPU, 128 GB RAM
      cpu_platform   = "Intel Emerald Rapids"
      data_disk_size = 3840 # 3.84 TB SSD
      boot_disk_size = 100
      boot_disk_type = "hyperdisk-balanced"
      data_disk_type = "hyperdisk-balanced"
    }

    # Small, low cost, single developer GEM variant.
    dev-and-test = {
      machine_type   = "n4-standard-8" # 8 vCPU, 32 GB RAM
      cpu_platform   = "Intel Emerald Rapids"
      data_disk_size = 150 # 150 GiB SSD
      boot_disk_size = 100
      boot_disk_type = "hyperdisk-balanced"
      data_disk_type = "hyperdisk-balanced"
    }
  }

  selected_hardware_variant = contains(keys(local.hardware_variants), var.hardware_variant) ? var.hardware_variant : "g2-small-64gb"
  hardware_config           = local.hardware_variants[local.selected_hardware_variant]
}

resource "terraform_data" "hardware_variant_validation" {
  lifecycle {
    precondition {
      condition     = contains(keys(local.hardware_variants), var.hardware_variant)
      error_message = "🚫 ERROR: The hardware_variant value '${var.hardware_variant}' must be one of: ${join(", ", keys(local.hardware_variants))}."
    }
  }
}

# ==============================================================================
# GDC Emulation Node Disks & Instances
# ==============================================================================

resource "google_compute_disk" "gdc_data_disks" {
  for_each = local.vms
  name     = "${each.value}-data"
  type     = local.hardware_config.data_disk_type
  zone     = var.zone
  size     = local.hardware_config.data_disk_size
  project  = var.project_id
}

resource "google_compute_instance" "gdc_vms" {
  for_each     = local.vms
  name         = each.value
  machine_type = local.hardware_config.machine_type
  zone         = var.zone
  project      = var.project_id

  min_cpu_platform = local.hardware_config.cpu_platform

  tags = ["http-server", "https-server"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = local.hardware_config.boot_disk_size
      type  = local.hardware_config.boot_disk_type
    }
  }

  attached_disk {
    source      = google_compute_disk.gdc_data_disks[each.key].id
    device_name = "data"
  }

  network_interface {
    network    = data.google_compute_network.gdc_vpc.self_link
    subnetwork = data.google_compute_subnetwork.gdc_subnet.self_link
  }

  can_ip_forward = true

  shielded_instance_config {
    enable_secure_boot          = false
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  advanced_machine_features {
    enable_nested_virtualization = true
  }

  metadata = {
    cluster_id     = var.cluster_name
    bmctl_version  = var.bmctl_version
    enable-oslogin = "FALSE"
    ssh-keys       = "gem:${lookup(data.google_compute_instance.gem_admin_ws.metadata, "workstation_pubkey", "")}"
    user-data      = <<-EOF
#cloud-config
bootcmd:
  # Initialize the secondary disk with a GPT label
  - parted -s /dev/disk/by-id/google-data mklabel gpt
  # Create a partition for node_storage (leaves the rest unpartitioned for cluster SDS)
  - parted -s /dev/disk/by-id/google-data mkpart node_storage ext4 0% ${var.node_storage_size}
runcmd:
  # Wait for the partition to populate in /dev
  - udevadm settle
  # Format and mount the node_storage partition (Partition 1 of the secondary disk)
  - mkfs.ext4 -F /dev/disk/by-id/google-data-part1
  - mkdir -p /mnt/node_storage
  - mount /dev/disk/by-id/google-data-part1 /mnt/node_storage
  - echo "UUID=$(blkid -s UUID -o value /dev/disk/by-id/google-data-part1) /mnt/node_storage ext4 defaults 0 2" >> /etc/fstab
EOF
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}
