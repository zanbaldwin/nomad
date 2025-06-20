data_dir = "/opt/consul/data"
datacenter = "hetzner"
client_addr = "0.0.0.0"
bind_addr = "${node_private_ip}"
advertise_addr = "${node_private_ip}"
# For Consul servers
server = true
bootstrap_expect = ${consul_server_count}
# Use JSON-encoded list from Terraform for start_join to form cluster
retry_join = ${consul_server_ips}
ui_config {
    # HTTP API is enabled by default
    enabled = true
}
# ACL Configuration
acl = {
    enabled = true
    default_policy = "deny"
    enable_token_persistence = true
}