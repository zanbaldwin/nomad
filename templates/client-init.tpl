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
            # Use JSON-encoded list from Terraform for start_join
            start_join = ${consul_server_ips}
            server = false
            ui_config {
                enabled = true # Can disable for clients if not needed
            }
    -   path: /etc/nomad.d/nomad.hcl
        permissions: '0644'
        content: |
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
                    postgres_data = {
                        path = "/mnt/data/postgres"
                        read_only = false
                    }
                    garage_data = {
                        path = "/mnt/data/garage"
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
            address = "${node_private_ip}:8500" # Self-reference Consul running on this client
            client_auto_join = true
            auto_advertise = true
            }

runcmd:
    - set -ex
    - echo "Applying sysctl changes..."
    - sysctl --system

    # Mount Hetzner volumes for stateful clients
    % if mount_volumes ~}
    - echo "Mounting volumes..."
    - mkdir -p /mnt/data/postgres
    - mkdir -p /mnt/data/garage
    # Format and mount volumes. Hetzner volumes are already formatted if `format = "ext4"` in TF.
    # So we just mount them.
    # Use device by-id for stable paths
    - mount -o discard,defaults /dev/disk/by-id/scsi-0HC_Volume_${volume_names[0]} ${volume_mount_points[0]}
    - mount -o discard,defaults /dev/disk/by-id/scsi-0HC_Volume_${volume_names[1]} ${volume_mount_points[1]}
    # Add to fstab for persistence across reboots
    - echo "/dev/disk/by-id/scsi-0HC_Volume_${volume_names[0]} ${volume_mount_points[0]} ext4 defaults,nofail 0 2" | tee -a /etc/fstab
    - echo "/dev/disk/by-id/scsi-0HC_Volume_${volume_names[1]} ${volume_mount_points[1]} ext4 defaults,nofail 0 2" | tee -a /etc/fstab
    % endif ~}

    # Install Docker
    - apt-get update
    - apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    - mkdir -p /etc/apt/keyrings
    - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    - apt-get update
    - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    - usermod -aG docker ubuntu # Add ubuntu user to docker group

    # Install Consul and Nomad
    - CONSUL_VERSION="1.18.1" # !!! Check for latest stable version before deploying !!!
    - NOMAD_VERSION="1.7.6"   # !!! Check for latest stable version before deploying !!!
    - curl -LO https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
    - curl -LO https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip
    - unzip consul_${CONSUL_VERSION}_linux_amd64.zip -d /usr/local/bin
    - unzip nomad_${NOMAD_VERSION}_linux_amd64.zip -d /usr/local/bin
    - rm consul_${CONSUL_VERSION}_linux_amd64.zip nomad_${NOMAD_VERSION}_linux_amd64.zip

    # Create data directories
    - mkdir -p /opt/consul/data
    - mkdir -p /opt/nomad/data

    # Create systemd service files for Consul
    -   |
        cat <<EOF > /etc/systemd/system/consul.service
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
            EOF

    # Create systemd service files for Nomad
    -   |
        cat <<EOF > /etc/systemd/system/nomad.service
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
            EOF

    -   systemctl daemon-reload
    -   systemctl enable consul.service
    -   systemctl start consul.service
    -   systemctl enable nomad.service
    -   systemctl start nomad.service
    -   echo "Nomad client setup complete!"
