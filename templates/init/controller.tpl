#cloud-config

write_files:
    -   path: '/root/.ssh/cluster'
        permissions: '0600'
        content: |
            ${indent(12, cluster_ssh_private_key)}
    -   path: '/etc/sysctl.d/99-vm-max-map-count.conf'
        permissions: '0644'
        content: |
            ${indent(12, file("${path}/templates/system/99-vm-max-map-count.conf"))}
    -   path: '/opt/install-docker.sh'
        permissions: '0755'
        content: |
            ${indent(12, file("${path}/templates/script/install-docker.sh"))}
    -   path: '/opt/install-consul.sh'
        permissions: '0755'
        content: |
            ${indent(12, templatefile("${path}/templates/script/install-consul.sh", {
                consul_version = "1.21.1",
            }))}
    -   path: '/etc/consul.d/consul.hcl'
        permissions: '0644'
        content: |
            ${indent(12, templatefile("${path}/templates/consul/controller.hcl", {
                node_private_ip = node_private_ip,
                consul_controller_count = consul_controller_count,
                consul_controller_ips = consul_controller_ips
            }))}
    -   path: '/etc/systemd/system/consul.service'
        permissions: '0644'
        content: |
            ${indent(12, file("${path}/templates/system/consul.service"))}
    -   path: '/opt/install-nomad.sh'
        permissions: '0755'
        content: |
            ${indent(12, templatefile("${path}/templates/script/install-nomad.sh", {
                nomad_version = "1.10.2",
            }))}
    -   path: '/etc/nomad.d/nomad.hcl'
        permissions: '0644'
        content: |
            ${indent(12, templatefile("${path}/templates/nomad/controller.hcl", {
                node_private_ip = node_private_ip,
                nomad_controller_count = nomad_controller_count,
                nomad_controller_ips = nomad_controller_ips,
            }))}
    -   path: '/etc/systemd/system/nomad.service'
        permissions: '0644'
        content: |
            ${indent(12, file("${path}/templates/system/nomad.service"))}
    -   path: '/opt/bootstrap-acls.sh'
        permissions: '0755'
        content: |
            ${indent(12, templatefile("${path}/templates/script/bootstrap-acls.sh", {
                node_private_ip = node_private_ip,
                consul_controller_ips = consul_controller_ips,
            }))}
    -   path: '/opt/setup-acl-tokens.sh'
        permissions: '0755'
        content: |
            ${indent(12, templatefile("${path}/templates/script/setup-acl-tokens.sh", {
                node_private_ip = node_private_ip,
                consul_controller_ips = consul_controller_ips
            }))}

runcmd:
    - set -ex
    # Apply the "vm-max-map-count" setting.
    - sysctl --system

    # Setup cluster SSH keys
    - mkdir -p '/root/.ssh'
    - chmod 700 '/root/.ssh'
    - echo "from=\"10.0.0.0/16\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding $(ssh-keygen -f '/root/.ssh/cluster' -y)" >> '/root/.ssh/authorized_keys'
    - chmod 600 '/root/.ssh/authorized_keys'

    # Required Tools
    - apt-get update
    - apt-get install -y ca-certificates curl jq unzip

    # Install Docker
    # (Nomad controllers don't typically need Docker, but it's often convenient for management tools)
    - bash '/opt/install-docker.sh'
    # Install Consul
    - mkdir -p '/opt/consul/data'
    - bash '/opt/install-consul.sh'
    # Install Nomad
    - mkdir -p '/opt/nomad/data'
    - bash '/opt/install-nomad.sh'

    # SystemD Services
    - systemctl daemon-reload
    - systemctl enable consul.service
    - systemctl start consul.service
    - systemctl enable nomad.service
    - systemctl start nomad.service

    # Bootstrap ACLs (run in background to avoid blocking cloud-init)
    - nohup /opt/bootstrap-acls.sh >'/var/log/bootstrap-acls.log' 2>&1 &
    # Setup ACL tokens for nodes/agents (run in background)
    - nohup /opt/setup-acl-tokens.sh >'/var/log/setup-acl-tokens.log' 2>&1 &
