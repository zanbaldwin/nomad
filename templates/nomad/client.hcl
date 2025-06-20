data_dir = "/opt/nomad/data"
datacenter = "hetzner"
log_level = "INFO"

server {
    enabled = false
}

client {
    enabled = true
    network_interface = "eth0"
    # Use JSON-encoded list from Terraform for servers
    servers = ${nomad_server_ips}
    node_class = "${nomad_node_class}" # Custom class for scheduling
    options = {
        "docker.privileged.enabled" = "false" # Set to "true" only if required by a specific workload
        "docker.volumes.enabled"    = "true"
        "docker.namespaces.enabled" = "false" # Useful if using Docker's native multi-tenancy (not used here)
    }
    # Define host volumes if this is a stateful client
    % if mount_volumes ~}
    host_volumes = {
        stateful_data = {
            path = "/mnt/data"
            read_only = false
        }
    }
    % endif ~}
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
    address = "127.0.0.1:8500" # Connect to local Consul agent
    client_auto_join = true
    auto_advertise = true
}