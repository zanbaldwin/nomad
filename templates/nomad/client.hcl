data_dir = "/opt/nomad/data"
datacenter = "hetzner"
log_level = "INFO"

server {
    enabled = false
}

client {
    enabled = true
    network_interface = "eth0"
    # Use JSON-encoded list from OpenTofu for servers.
    servers = ${nomad_controller_ips}
    options = {
        # Set to "true" only if required by a specific workload.
        "docker.privileged.enabled" = "false"
        "docker.volumes.enabled"    = "true"
        # Useful if using Docker's native multi-tenancy (not used here currently).
        "docker.namespaces.enabled" = "false"
    }
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

consul {
    address = "127.0.0.1:8500"
    client_auto_join = true
    auto_advertise = true
    # This value will get replaced with the token generated on, and extracted from, the first controller node.
    token = "{{NOMAD_CONSUL_TOKEN}}"
}

acl {
    enabled = true
}
