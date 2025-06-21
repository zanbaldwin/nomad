output "server_controller_ips_public" {
  description = "Public IP addresses of the Nomad server nodes"
  value       = hcloud_server.controller_nodes.*.ipv4_address
}

output "server_controller_ips_private" {
  description = "Private IP addresses of the Nomad server nodes"
  value       = [for server in hcloud_server.controller_nodes : [for net in server.network : net.ip][0]]
}

output "server_controller_names" {
  description = "Names of the Nomad server nodes"
  value       = hcloud_server.controller_nodes.*.name
}

output "server_client_ips_public" {
  description = "Public IP addresses of the Nomad client nodes"
  value       = hcloud_server.client_nodes.*.ipv4_address
}

output "server_client_ips_private" {
  description = "Private IP addresses of the Nomad client nodes"
  value       = [for server in hcloud_server.client_nodes : [for net in server.network : net.ip][0]]
}

output "nomad_ui_url" {
  description = "URL to access Nomad UI (requires ACL token) (via public IP of any controller node)"
  value       = "http://${hcloud_server.controller_nodes[0].ipv4_address}:4646"
}

output "consul_ui_url" {
  description = "URL to access Consul UI (requires ACL token) (via public IP of any controller node)"
  value       = "http://${hcloud_server.controller_nodes[0].ipv4_address}:8500"
}

output "acl_token_retrieval" {
  description = "Commands to retrieve ACL tokens after deployment"
  value = {
    nomad_token  = "ssh root@${hcloud_server.controller_nodes[0].ipv4_address} 'cat /opt/nomad-root-token'"
    consul_token = "ssh root@${hcloud_server.controller_nodes[0].ipv4_address} 'cat /opt/consul-root-token'"
  }
}
