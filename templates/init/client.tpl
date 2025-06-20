#cloud-config

write_files:
    -   path: '/etc/sysctl.d/99-vm-max-map-count.conf'
        permissions: '0644'
        content: |
            ${indent(12, file("${path.module}/templates/system/99-vm-max-map-count.conf"))}
    -   path: '/etc/consul.d/consul.hcl'
        permissions: '0644'
        content: |
            ${indent(12, templatefile("${path.module}/templates/consul/client.hcl", {
                node_private_ip = node_private_ip,
                consul_server_ips = consul_server_ips
            }))}
    -   path: '/etc/systemd/system/consul.service'
        permissions: '0644'
        content: |
            ${indent(12, file("${path.module}/templates/system/consul.service"))}
    -   path: '/etc/nomad.d/nomad.hcl'
        permissions: '0644'
        content: |
            ${indent(12, templatefile("${path.module}/templates/nomad/client.hcl", {
                node_private_ip = node_private_ip,
                nomad_server_ips = nomad_server_ips,
                nomad_node_class = nomad_node_class,
                mount_volumes = mount_volumes,
                volume_mount_points = volume_mount_points
            }))}
    -   path: '/etc/systemd/system/nomad.service'
        permissions: '0644'
        content: |
            ${indent(12, file("${path.module}/templates/system/nomad.service"))}
    -   path: '/opt/setup-acl-tokens.sh'
        permissions: '0755'
        content: |
            ${indent(12, templatefile("${path.module}/templates/scripts/setup-acl-tokens.sh", {
                consul_server_ips = consul_server_ips
            }))}

runcmd:
    - set -ex
    - echo "Applying sysctl changes..."
    - sysctl --system

    # Mount Hetzner volumes for stateful clients
    %{ if mount_volumes ~}
    - echo "Mounting volumes..."
    %{ for idx, mount_point in volume_mount_points ~}
    - mkdir -p ${mount_point}
    %{ endfor ~}
    # Format and mount volumes. Hetzner volumes are already formatted if `format = "ext4"` in TF.
    # So we just mount them.
    # Use device by-id for stable paths
    %{ for idx, volume_name in volume_names ~}
    - mount -o discard,defaults /dev/disk/by-id/scsi-0HC_Volume_${volume_name} ${volume_mount_points[idx]}
    - echo "/dev/disk/by-id/scsi-0HC_Volume_${volume_name} ${volume_mount_points[idx]} ext4 defaults,nofail 0 2" | tee -a /etc/fstab
    %{ endfor ~}
    %{ endif ~}

    # Install Docker
    - apt-get update
    - apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release jq unzip
    - mkdir -p /etc/apt/keyrings
    - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    - apt-get update
    - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    # Docker is available for root user

    # Install Consul and Nomad
    - CONSUL_VERSION="1.21.1" # !!! Check for latest stable version before deploying !!!
    - NOMAD_VERSION="1.10.2"  # !!! Check for latest stable version before deploying !!!
    - curl -LO https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_linux_amd64.zip
    - curl -LO https://releases.hashicorp.com/nomad/$${NOMAD_VERSION}/nomad_$${NOMAD_VERSION}_linux_amd64.zip
    - unzip -o consul_$${CONSUL_VERSION}_linux_amd64.zip -d /usr/local/bin
    - unzip -o nomad_$${NOMAD_VERSION}_linux_amd64.zip -d /usr/local/bin
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
    - echo "Nomad client setup complete!"

    # Setup ACL tokens (run in background)
    - nohup /opt/setup-acl-tokens.sh > /var/log/setup-acl-tokens.log 2>&1 &
