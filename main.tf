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
    # Could use "tls_private_key.cluster_ssh_key.private_key_openssh", but that would change every time this script is
    # provisioned without previous state. Use pre-generated private key restricted to the private network.
    cluster_ssh_private_key = file("${path.module}/templates/system/id_ed25519"),
  })

  # Ensure network is ready before creating servers
  depends_on = [
    hcloud_network_subnet.cluster_subnet
  ]

  labels = {
    # Assuming a single shared instance for the (parent) organization
    organization = var.organization_name
    project      = var.project_name
    role         = "controller"
  }
}

# Nomad Client Nodes (stateless by default)
# =========================================

resource "hcloud_server" "client_nodes" {
  count       = var.server_client_count
  name        = "${var.organization_name}-${var.project_name}-client-${count.index}"
  image       = var.server_base_image
  server_type = var.server_client_type
  location    = var.region
  ssh_keys    = [data.hcloud_ssh_key.default.id]
  public_net {
    ipv4_enabled = false
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.cluster_network.id
    # IP range after controller nodes, e.g., 10.0.0.24, 10.0.0.25 etc.
    ip = cidrhost(hcloud_network_subnet.cluster_subnet.ip_range, count.index + 24)
  }

  user_data = templatefile("${path.module}/templates/init/client.tpl", {
    path                  = path.module,
    node_private_ip       = cidrhost(hcloud_network_subnet.cluster_subnet.ip_range, count.index + 24),
    consul_controller_ips = jsonencode([for i in range(var.server_controller_count) : cidrhost(hcloud_network_subnet.cluster_subnet.ip_range, i + 16)]),
    nomad_controller_ips  = jsonencode([for i in range(var.server_controller_count) : cidrhost(hcloud_network_subnet.cluster_subnet.ip_range, i + 16)]),
    # Could use "tls_private_key.cluster_ssh_key.private_key_openssh", but that would change every time this script is
    # provisioned without previous state. Use pre-generated private key restricted to the private network.
    cluster_ssh_private_key = file("${path.module}/templates/system/id_ed25519"),
  })

  depends_on = [
    hcloud_server.controller_nodes
  ]

  labels = {
    # Assuming a single shared instance for the (parent) organization
    organization = var.organization_name
    project      = var.project_name
    role         = "client"
    node_class   = "stateless"
  }
}

# Load Balancer
# =============

# Forward all HTTP(S) traffic (80/443) to all client nodes across the private network.

resource "hcloud_load_balancer" "cluster_lb" {
  name               = "${var.organization_name}-${var.project_name}-lb"
  location           = var.region
  load_balancer_type = var.load_balancer_type
  labels = {
    organization = var.organization_name
    project      = var.project_name
    role         = "load-balancer"
  }
}

resource "hcloud_load_balancer_network" "cluster_lb_network" {
  load_balancer_id = hcloud_load_balancer.cluster_lb.id
  network_id       = hcloud_network.cluster_network.id
  ip               = "10.0.0.10" # Static IP within subnet
}

resource "hcloud_load_balancer_service" "http" {
  load_balancer_id = hcloud_load_balancer.cluster_lb.id
  protocol         = "http"
  listen_port      = 80
  destination_port = 80
  health_check {
    protocol = "tcp"
    port     = 80
    interval = 15
    timeout  = 10
    retries  = 3
  }
}

resource "hcloud_load_balancer_service" "https" {
  load_balancer_id = hcloud_load_balancer.cluster_lb.id
  protocol         = "tcp"
  listen_port      = 443
  destination_port = 443
  health_check {
    protocol = "tcp"
    port     = 443
    interval = 15
    timeout  = 10
    retries  = 3
  }
}

resource "hcloud_load_balancer_target" "client_targets" {
  count            = var.server_client_count
  type             = "server"
  load_balancer_id = hcloud_load_balancer.cluster_lb.id
  server_id        = hcloud_server.client_nodes[count.index].id
  use_private_ip   = true
  depends_on       = [hcloud_load_balancer_network.cluster_lb_network]
}
