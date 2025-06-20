data_dir = "/opt/consul/data"
datacenter = "hetzner"
client_addr = "0.0.0.0"
bind_addr = "${node_private_ip}"
advertise_addr = "${node_private_ip}"
# Use JSON-encoded list from Terraform for retry_join
retry_join = ${consul_server_ips}
server = false
ui_config {
    # Can disable for clients if not needed
    enabled = true
}
# ACL Configuration
acl = {
    enabled = true
    default_policy = "deny"
    enable_token_persistence = true
}