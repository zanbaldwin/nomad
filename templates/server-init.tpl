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
            # ACL Configuration
            acl = {
                enabled = true
                default_policy = "deny"
                enable_token_persistence = true
            }
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
            # ACL Configuration
            acl {
                enabled = true
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
    -   path: /opt/bootstrap-acls.sh
        permissions: '0755'
        content: |
            #!/bin/bash
            set -e

            echo "Waiting for Consul to be ready..."
            while ! consul members > /dev/null 2>&1; do
                sleep 5
            done

            echo "Waiting for Nomad to be ready..."
            while ! nomad node status > /dev/null 2>&1; do
                sleep 5
            done

            # Bootstrap Consul ACLs (only run on first server)
            if [ "${node_private_ip}" = "$(echo '${consul_server_ips}' | jq -r '.[0]')" ]; then
                echo "Bootstrapping Consul ACLs..."
                if ! consul acl bootstrap > /tmp/consul-bootstrap.json 2>/dev/null; then
                    echo "Consul ACL already bootstrapped or failed"
                else
                    echo "Consul ACL bootstrap successful"
                    CONSUL_TOKEN=$(cat /tmp/consul-bootstrap.json | jq -r '.SecretID')
                    echo "CONSUL_HTTP_TOKEN=$CONSUL_TOKEN" >> /etc/environment
                    export CONSUL_HTTP_TOKEN="$CONSUL_TOKEN"

                    # Create Nomad agent policy for Consul integration
                    consul acl policy create \
                        -name "nomad-agent" \
                        -description "Nomad Agent Policy" \
                        -rules 'agent_prefix "" { policy = "write" }
                                node_prefix "" { policy = "write" }
                                service_prefix "" { policy = "write" }
                                acl = "write"'

                    # Create token for Nomad agents
                    consul acl token create \
                        -description "Nomad Agent Token" \
                        -policy-name "nomad-agent" > /tmp/nomad-consul-token.json

                    NOMAD_CONSUL_TOKEN=$(cat /tmp/nomad-consul-token.json | jq -r '.SecretID')
                    echo "NOMAD_CONSUL_TOKEN=$NOMAD_CONSUL_TOKEN" >> /etc/environment
                fi

                # Bootstrap Nomad ACLs
                echo "Bootstrapping Nomad ACLs..."
                if ! nomad acl bootstrap > /tmp/nomad-bootstrap.json 2>/dev/null; then
                    echo "Nomad ACL already bootstrapped or failed"
                else
                    echo "Nomad ACL bootstrap successful"
                    NOMAD_TOKEN=$(cat /tmp/nomad-bootstrap.json | jq -r '.SecretID')
                    echo "NOMAD_TOKEN=$NOMAD_TOKEN" >> /etc/environment

                    # Save tokens to files for easy access
                    echo "$CONSUL_TOKEN" > /opt/consul-root-token
                    echo "$NOMAD_TOKEN" > /opt/nomad-root-token
                    echo "$NOMAD_CONSUL_TOKEN" > /opt/nomad-consul-token
                    chmod 0600 /opt/*-token
                fi
            fi

runcmd:
    - set -ex
    - echo "Applying sysctl changes..."
    - sysctl --system

    # Install Docker (Nomad Servers don't *need* Docker, but it's often convenient for management tools)
    - apt-get update
    - apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release jq
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

    # Bootstrap ACLs (run in background to avoid blocking cloud-init)
    - nohup /opt/bootstrap-acls.sh > /var/log/bootstrap-acls.log 2>&1 &
