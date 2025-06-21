#cloud-config

write_files:
    -   path: '/etc/sysctl.d/99-vm-max-map-count.conf'
        permissions: '0644'
        content: |
            ${indent(12, file("${path}/templates/system/99-vm-max-map-count.conf"))}
    -   path: '/etc/consul.d/consul.hcl'
        permissions: '0644'
        content: |
            ${indent(12, templatefile("${path}/templates/consul/server.hcl", {
                node_private_ip = node_private_ip,
                consul_server_count = consul_server_count,
                consul_server_ips = consul_server_ips
            }))}
    -   path: '/etc/systemd/system/consul.service'
        permissions: '0644'
        content: |
            ${indent(12, file("${path}/templates/system/consul.service"))}
    -   path: '/etc/nomad.d/nomad.hcl'
        permissions: '0644'
        content: |
            ${indent(12, templatefile("${path}/templates/nomad/server.hcl", {
                node_private_ip = node_private_ip,
                nomad_server_count = nomad_server_count,
                nomad_server_ips = nomad_server_ips
            }))}
    -   path: '/etc/systemd/system/nomad.service'
        permissions: '0644'
        content: |
            ${indent(12, file("${path}/templates/system/nomad.service"))}
    -   path: '/opt/bootstrap-acls.sh'
        permissions: '0755'
        content: |
            ${indent(12, templatefile("${path}/templates/scripts/bootstrap-acls.sh", {
                node_private_ip = node_private_ip,
                consul_server_ips = consul_server_ips
            }))}

runcmd:
    - set -ex
    - echo "Applying sysctl changes..."
    - sysctl --system

    # Install Docker (Nomad Servers don't *need* Docker, but it's often convenient for management tools)
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
    - NOMAD_VERSION="1.10.2"   # !!! Check for latest stable version before deploying !!!
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
    - echo "Nomad server setup complete!"

    # Bootstrap ACLs (run in background to avoid blocking cloud-init)
    - nohup /opt/bootstrap-acls.sh > /var/log/bootstrap-acls.log 2>&1 &
