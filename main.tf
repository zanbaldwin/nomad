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
  name     = "${var.organization_name}-${var.project_name}-network"
  ip_range = "10.0.0.0/16"
}
# Subnet
resource "hcloud_network_subnet" "cluster_subnet" {
  network_id   = hcloud_network.cluster_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.0.0/24"
}

# Nomad Controller Nodes (w/ embedded Consul)
# ===========================================

resource "hcloud_server" "controller_nodes" {
  count       = var.server_controller_count
  name        = "${var.organization_name}-${var.project_name}-controller-${count.index}"
  image       = var.server_base_image
  server_type = var.server_controller_type
  location    = var.region
  ssh_keys    = [data.hcloud_ssh_key.default.id]

  network {
    network_id = hcloud_network.cluster_network.id
    ip         = cidrhost(hcloud_network_subnet.cluster_subnet.ip_range, count.index + 16) # 10.0.0.16, 10.0.0.17, etc.
  }

  user_data = templatefile("${path.module}/templates/init/controller.tpl", {
    path                    = path.module,
    node_private_ip         = cidrhost(hcloud_network_subnet.cluster_subnet.ip_range, count.index + 16),
    consul_controller_ips   = jsonencode([for i in range(var.server_controller_count) : cidrhost(hcloud_network_subnet.cluster_subnet.ip_range, i + 16)]),
    nomad_controller_ips    = jsonencode([for i in range(var.server_controller_count) : cidrhost(hcloud_network_subnet.cluster_subnet.ip_range, i + 16)]),
    consul_controller_count = var.server_controller_count,
    nomad_controller_count  = var.server_controller_count,
  })

  # Ensure network is ready before creating servers
  depends_on = [
    hcloud_network_subnet.cluster_subnet
  ]

  # Labels for identification
  labels = {
    project = var.project_name
    role    = "nomad-controller"
    # Assuming a single shared instance for the (parent) organization
    organization = var.organization_name
  }
}
