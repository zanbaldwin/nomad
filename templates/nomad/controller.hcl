data_dir = "/opt/nomad/data"
datacenter = "hetzner"
log_level = "INFO"
# Nomad Server configuration
server {
    enabled = true
    bootstrap_expect = ${nomad_controller_count}
    # List of private IPs for the Nomad servers to join
    retry_join = ${nomad_controller_ips}
}
# Nomad Client is disabled on server nodes by default for clean separation
client {
    enabled = false
}
addresses {
    http = "0.0.0.0"
    rpc  = "0.0.0.0"
    serf = "0.0.0.0"
}
advertise {
    http = "${node_private_ip}:4646"
    rpc  = "${node_private_ip}:4647"
    serf = "${node_private_ip}:4648"
}
# ACL Configuration
acl {
    enabled = true
}
consul {
    # Self-reference Consul running on this server
    address = "${node_private_ip}:8500"
    client_auto_join = true
    auto_advertise = true
}
