# Hetzner Cloud provider
# ======================

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.51"
    }
  }
}
provider "hcloud" {
  token = var.hcloud_token
}
data "hcloud_ssh_key" "default" {
  name = var.ssh_key_name
}

# Networking
# ==========

# Private network for Nomad/Consul communication
resource "hcloud_network" "cluster_network" {
  name     = "${var.project_name}-network"
  ip_range = "10.0.0.0/16"
}
# Subnet
resource "hcloud_network_subnet" "cluster_subnet" {
  network_id   = hcloud_network.cluster_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.0.0/24"
}
