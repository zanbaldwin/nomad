output "server_controller_ips_public" {
  description = "Public IP addresses of the Nomad controller nodes"
  value       = hcloud_server.controller_nodes.*.ipv4_address
}

output "server_controller_names" {
  description = "Names of the Nomad server nodes"
  value       = hcloud_server.controller_nodes.*.name
}

output "server_client_ips_private" {
  description = "Private IP addresses of the Nomad client nodes"
  value       = [for server in hcloud_server.client_nodes : [for net in server.network : net.ip][0]]
}

output "load_balancer_ip_public" {
  description = "Public IP address of the load balancer (point your domains here)"
  value       = hcloud_load_balancer.cluster_lb.ipv4
}

output "nomad_ui_urls" {
  description = "URLs to access Nomad UI (requires ACL token) on each controller"
  value       = [for ip in hcloud_server.controller_nodes.*.ipv4_address : "http://${ip}:4646"]
}

output "consul_ui_urls" {
  description = "URLs to access Consul UI (requires ACL token) on each controller"
  value       = [for ip in hcloud_server.controller_nodes.*.ipv4_address : "http://${ip}:8500"]
}

output "ssh_instructions" {
  description = "SSH access instructions"
  value = {
    controller_direct     = "ssh root@<CONTROLLER_IP>"
    client_via_controller = "ssh -J root@${hcloud_server.controller_nodes[0].ipv4_address} root@<CLIENT_PRIVATE_IP>"
    example_client_access = "ssh -J root@${hcloud_server.controller_nodes[0].ipv4_address} root@${[for server in hcloud_server.client_nodes : [for net in server.network : net.ip][0]][0]}"
  }
}

output "acl_token_retrieval" {
  description = "Commands to retrieve ACL tokens after deployment"
  value = {
    nomad_token  = "ssh root@${hcloud_server.controller_nodes[0].ipv4_address} 'cat /opt/nomad-root-token'"
    consul_token = "ssh root@${hcloud_server.controller_nodes[0].ipv4_address} 'cat /opt/consul-root-token'"
  }
}
