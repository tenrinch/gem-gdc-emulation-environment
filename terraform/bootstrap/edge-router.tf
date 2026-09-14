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
# Edge Router Compute Engine Instance
# ==============================================================================

resource "google_compute_instance" "edge_router" {
  name         = var.edge_router_name
  machine_type = var.edge_router_machine_type
  zone         = var.zone
  project      = var.project_id

  tags = ["http-server", "https-server"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = google_compute_network.gdc_vpc.self_link
    subnetwork = google_compute_subnetwork.gdc_subnet.self_link
  }

  can_ip_forward = true

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  deletion_protection = var.deletion_protection

  metadata = {
    enable-oslogin = "FALSE"
    ssh-keys       = "gem:${lookup(google_compute_instance.admin_ws.metadata, "workstation_pubkey", "")}"
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}
