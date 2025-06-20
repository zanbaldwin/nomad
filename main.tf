# Configure Hetzner Cloud provider
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

# Data source for SSH key
data "hcloud_ssh_key" "default" {
  name = var.ssh_key_name
}

# Create a private network for Nomad/Consul communication
resource "hcloud_network" "nomad_cluster_network" {
  name     = "${var.project_name}-network"
  ip_range = "10.0.0.0/16"
}

# Add a subnet to the network
resource "hcloud_network_subnet" "nomad_cluster_subnet" {
  network_id   = hcloud_network.nomad_cluster_network.id
  type         = "cloud"
  network_zone = var.region
  ip_range     = "10.0.0.0/24"
}

# -----------------------------------------------------------------------------
# Nomad Server Instances (and embedded Consul Servers)
# -----------------------------------------------------------------------------

resource "hcloud_server" "nomad_servers" {
  count       = var.nomad_server_count
  name        = "${var.project_name}-nomad-server-${count.index}"
  image       = "ubuntu-24.04"
  server_type = var.server_type_nomad_server
  location    = var.region
  ssh_keys    = [data.hcloud_ssh_key.default.id]

  network {
    network_id = hcloud_network.nomad_cluster_network.id
    ip         = cidrhost(hcloud_network_subnet.nomad_cluster_subnet.ip_range, count.index + 16) # 10.0.0.16, 10.0.0.17, etc.
  }

  user_data = templatefile("${path.module}/templates/server-init.tpl", {
    node_private_ip     = cidrhost(hcloud_network_subnet.nomad_cluster_subnet.ip_range, count.index + 16),
    consul_server_ips   = jsonencode([for i in range(var.nomad_server_count) : cidrhost(hcloud_network_subnet.nomad_cluster_subnet.ip_range, i + 16)]),
    nomad_server_ips    = jsonencode([for i in range(var.nomad_server_count) : cidrhost(hcloud_network_subnet.nomad_cluster_subnet.ip_range, i + 16)]),
    consul_server_count = var.nomad_server_count, # Consul bootstrap_expect will be nomad_server_count
    nomad_server_count  = var.nomad_server_count
  })

  # Ensure network is ready before creating servers
  depends_on = [
    hcloud_network_subnet.nomad_cluster_subnet
  ]

  # Labels for identification
  labels = {
    project = var.project_name
    role    = "nomad-server"
    client  = "zan" # Assuming a single shared instance for the company
  }
}

# -----------------------------------------------------------------------------
# Nomad Client Instances (Stateful - with attached volumes)
# -----------------------------------------------------------------------------

resource "hcloud_volume" "stateful_data" {
  count     = var.nomad_client_stateful_count
  name      = "${var.project_name}-stateful-data-${count.index}"
  size      = var.volume_size_stateful
  location  = var.region # Volume must be in the same location as the server
  format    = "ext4"
  automount = false # Manual mount via cloud-init
}

resource "hcloud_server" "nomad_clients_stateful" {
  count       = var.nomad_client_stateful_count
  name        = "${var.project_name}-nomad-client-stateful-${count.index}"
  image       = "ubuntu-24.04"
  server_type = var.server_type_nomad_client_stateful
  location    = var.region
  ssh_keys    = [data.hcloud_ssh_key.default.id]

  network {
    network_id = hcloud_network.nomad_cluster_network.id
    # IP range starting after servers, e.g., 10.0.0.32, 10.0.0.33 etc.
    ip = cidrhost(hcloud_network_subnet.nomad_cluster_subnet.ip_range, count.index + 32)
  }


  user_data = templatefile("${path.module}/templates/client-init.tpl", {
    node_private_ip   = cidrhost(hcloud_network_subnet.nomad_cluster_subnet.ip_range, count.index + 32),
    consul_server_ips = jsonencode([for i in range(var.nomad_server_count) : cidrhost(hcloud_network_subnet.nomad_cluster_subnet.ip_range, i + 16)]),
    nomad_server_ips  = jsonencode([for i in range(var.nomad_server_count) : cidrhost(hcloud_network_subnet.nomad_cluster_subnet.ip_range, i + 16)]),
    nomad_node_class  = "stateful", # Custom node class for scheduling
    mount_volumes     = true,
    volume_names = [
      hcloud_volume.stateful_data[count.index].name
    ],
    volume_mount_points = ["/mnt/data"]
  })

  depends_on = [
    hcloud_server.nomad_servers
  ]

  labels = {
    project    = var.project_name
    role       = "nomad-client"
    node_class = "stateful"
    client     = "zan"
  }
}

# Volume attachments for stateful clients
resource "hcloud_volume_attachment" "stateful_attachment" {
  count     = var.nomad_client_stateful_count
  volume_id = hcloud_volume.stateful_data[count.index].id
  server_id = hcloud_server.nomad_clients_stateful[count.index].id
  automount = false
}

# -----------------------------------------------------------------------------
# Nomad Client Instances (Stateless)
# -----------------------------------------------------------------------------

resource "hcloud_server" "nomad_clients_stateless" {
  count       = var.nomad_client_stateless_count
  name        = "${var.project_name}-nomad-client-stateless-${count.index}"
  image       = "ubuntu-24.04"
  server_type = var.server_type_nomad_client_stateless
  location    = var.region
  ssh_keys    = [data.hcloud_ssh_key.default.id]

  network {
    network_id = hcloud_network.nomad_cluster_network.id
    # IP range after stateful clients, e.g., 10.0.0.64, 10.0.0.65 etc.
    ip = cidrhost(hcloud_network_subnet.nomad_cluster_subnet.ip_range, count.index + 64)
  }

  user_data = templatefile("${path.module}/templates/client-init.tpl", {
    node_private_ip     = cidrhost(hcloud_network_subnet.nomad_cluster_subnet.ip_range, count.index + 64),
    consul_server_ips   = jsonencode([for i in range(var.nomad_server_count) : cidrhost(hcloud_network_subnet.nomad_cluster_subnet.ip_range, i + 16)]),
    nomad_server_ips    = jsonencode([for i in range(var.nomad_server_count) : cidrhost(hcloud_network_subnet.nomad_cluster_subnet.ip_range, i + 16)]),
    nomad_node_class    = "stateless", # Custom node class for scheduling
    mount_volumes       = false,       # No volumes for stateless clients
    volume_names        = [],
    volume_mount_points = []
  })

  depends_on = [
    hcloud_server.nomad_servers
  ]

  labels = {
    project    = var.project_name
    role       = "nomad-client"
    node_class = "stateless"
    client     = "zan"
  }
}
