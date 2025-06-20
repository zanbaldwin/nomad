#cloud-config

write_files:
    -   path: /etc/sysctl.d/99-vm-max-map-count.conf
        permissions: '0644'
        content: |
            vm.max_map_count=262144
    -   path: /etc/consul.d/consul.hcl
        permissions: '0644'
        content: |
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
                enabled = true
            }
            # Enable HTTP API for management
            enable_http_cli = true
    -   path:  /etc/systemd/system/consul.service
        permissions: '0644'
        content: |
            [Unit]
            Description=HashiCorp Consul - A service mesh solution
            Documentation=https://www.consul.io/
            Requires=network-online.target
            After=network-online.target

            [Service]
            ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/ -data-dir=/opt/consul/data
            ExecReload=/usr/local/bin/consul reload
            KillMode=process
            Restart=on-failure
            LimitNOFILE=65536

            [Install]
            WantedBy=multi-user.target
    -   path: /etc/nomad.d/nomad.hcl
        permissions: '0644'
        content: |
            data_dir = "/opt/nomad/data"
            datacenter = "hetzner"
            log_level = "INFO"
            # Nomad Server configuration
            server {
                enabled = true
                bootstrap_expect = ${nomad_server_count}
                # List of private IPs for the Nomad servers to join
                retry_join = ${nomad_server_ips}
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
            consul {
                address = "${node_private_ip}:8500" # Self-reference Consul running on this server
                client_auto_join = true
                auto_advertise = true
            }
    -   path: /etc/systemd/system/nomad.service
        permissions: '0644'
        content: |
            [Unit]
            Description=HashiCorp Nomad
            Documentation=https://nomadproject.io/
            Wants=network-online.target
            After=network-online.target consul.service

            [Service]
            ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d/nomad.hcl
            ExecReload=/bin/kill -HUP $MAINPID
            LimitNOFILE=65536
            Restart=on-failure
            RestartSec=5
            Delegate=yes
            KillMode=process

            [Install]
            WantedBy=multi-user.target

runcmd:
    - set -ex
    - echo "Applying sysctl changes..."
    - sysctl --system

    # Install Docker (Nomad Servers don't *need* Docker, but it's often convenient for management tools)
    - apt-get update
    - apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    - mkdir -p /etc/apt/keyrings
    - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    - apt-get update
    - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    - usermod -aG docker ubuntu # Add ubuntu user to docker group

    # Install Consul and Nomad
    - CONSUL_VERSION="1.21.1" # !!! Check for latest stable version before deploying !!!
    - NOMAD_VERSION="1.10.2"   # !!! Check for latest stable version before deploying !!!
    - curl -LO https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_linux_amd64.zip
    - curl -LO https://releases.hashicorp.com/nomad/$${NOMAD_VERSION}/nomad_$${NOMAD_VERSION}_linux_amd64.zip
    - unzip consul_$${CONSUL_VERSION}_linux_amd64.zip -d /usr/local/bin
    - unzip nomad_$${NOMAD_VERSION}_linux_amd64.zip -d /usr/local/bin
    - rm consul_$${CONSUL_VERSION}_linux_amd64.zip nomad_$${NOMAD_VERSION}_linux_amd64.zip

    # Create data directories
    - mkdir -p /opt/consul/data
    - mkdir -p /opt/nomad/data

    # SystemD Services
    - systemctl daemon-reload
    - systemctl enable consul.service
    - systemctl start consul.service
    - systemctl enable nomad.service
    - systemctl start nomad.service
    - echo "Nomad server setup complete!"
