output "nomad_server_ips_public" {
  description = "Public IP addresses of the Nomad server nodes"
  value       = hcloud_server.nomad_servers.*.ipv4_address
}

output "nomad_server_ips_private" {
  description = "Private IP addresses of the Nomad server nodes"
  value       = [for server in hcloud_server.nomad_servers : [for net in server.network : net.ip][0]]
}

output "nomad_server_names" {
  description = "Names of the Nomad server nodes"
  value       = hcloud_server.nomad_servers.*.name
}

output "nomad_client_stateful_ips_public" {
  description = "Public IP addresses of the stateful Nomad client nodes"
  value       = hcloud_server.nomad_clients_stateful.*.ipv4_address
}

output "nomad_client_stateful_ips_private" {
  description = "Private IP addresses of the stateful Nomad client nodes"
  value       = [for server in hcloud_server.nomad_clients_stateful : [for net in server.network : net.ip][0]]
}

output "nomad_client_stateless_ips_public" {
  description = "Public IP addresses of the stateless Nomad client nodes"
  value       = hcloud_server.nomad_clients_stateless.*.ipv4_address
}

output "nomad_client_stateless_ips_private" {
  description = "Private IP addresses of the stateless Nomad client nodes"
  value       = [for server in hcloud_server.nomad_clients_stateless : [for net in server.network : net.ip][0]]
}

output "nomad_ui_access" {
  description = "URL for Nomad UI (access via the public IP of any server node)"
  value       = "http://${hcloud_server.nomad_servers[0].ipv4_address}:4646"
}

output "consul_ui_access" {
  description = "URL for Consul UI (access via the public IP of any server node)"
  value       = "http://${hcloud_server.nomad_servers[0].ipv4_address}:8500"
}
