#!/bin/bash
# This is a cloud-init template file. Bash "dollar-brace" variables should be double-dollar escaped `$$`.
set -e

function wait_for_token_local {
        # The bootstrapping script gets run in the background, so both script will be running concurrently.
        echo "Waiting for Nomad/Consul ACL bootstrap to complete on local machine..."
        while true; do
            # CONSUL_HTTP_TOKEN is required for the creation of the NOMAD_CONSUL_TOKEN, so the existence of one implies the existence of the other.
            if [ -f '/opt/nomad-consul-token' ]; then
                break
            fi
            sleep 10
        done
}

function wait_for_token_ssh {
    echo "Waiting for ACL bootstrap to complete on first controller node..."
    while true; do
        # CONSUL_HTTP_TOKEN is required for the creation of the NOMAD_CONSUL_TOKEN, so the existence of one implies the existence of the other.
        if ssh -i "/root/.ssh/cluster" -o "StrictHostKeyChecking=accept-new" -o "ConnectTimeout=5" "root@$${FIRST_CONTROLLER_NODE_IP}" "test -f '/opt/nomad-consul-token'" 2>/dev/null; then
            break
        fi
        sleep 10
    done
}

# ACL tokens are bootstrapped on the first controller node (most likely `10.0.0.16`).
FIRST_CONTROLLER_NODE_IP=$(echo '${consul_controller_ips}' | jq -r '.[0]')
if [ "${node_private_ip}" = "$${FIRST_CONTROLLER_NODE_IP}" ]; then
    wait_for_token_local
    export CONSUL_HTTP_TOKEN="$(cat '/opt/consul-root-token')"
    export NOMAD_CONSUL_TOKEN="$(cat '/opt/nomad-consul-token')"
    # Environment variables already set in bootstrapping script.
else
    wait_for_token_ssh
    export CONSUL_HTTP_TOKEN="$(ssh -i '/root/.ssh/cluster' -o 'StrictHostKeyChecking=accept-new' "root@$${FIRST_CONTROLLER_NODE_IP}" 'cat /opt/consul-root-token')"
    export NOMAD_CONSUL_TOKEN="$(ssh -i '/root/.ssh/cluster' -o 'StrictHostKeyChecking=accept-new' "root@$${FIRST_CONTROLLER_NODE_IP}" 'cat /opt/nomad-consul-token')"
    # Set environment variables for future use (don't save the Consul root token).
    echo "NOMAD_CONSUL_TOKEN=$${NOMAD_CONSUL_TOKEN}" >> /etc/environment
fi

# Update the placeholder in the Nomad configuration with Consul agent token.
sed -i "s|{{NOMAD_CONSUL_TOKEN}}|$${NOMAD_CONSUL_TOKEN}|g" /etc/nomad.d/nomad.hcl

# Depending how quickly the tokens were generated on the first controller node, SystemD services may still be starting...
echo "Waiting for Consul to be ready on local machine..."
while ! curl -fsSL "http://127.0.0.1:8500/v1/status/leader" >'/dev/null' 2>&1; do
    sleep 5
done

CONSUL_HTTP_TOKEN="$${CONSUL_HTTP_TOKEN}" consul acl set-agent-token agent "$${NOMAD_CONSUL_TOKEN}"
# Signal services to reload configuration after ACL setup
systemctl reload consul || systemctl restart consul
systemctl reload nomad || systemctl restart nomad
