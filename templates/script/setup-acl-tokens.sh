#!/bin/bash
set -e

# Get the first server IP for token retrieval
FIRST_SERVER=$(echo '${consul_controller_ips}' | jq -r '.[0]')

# Only run if this is not the first controller
if [ "${node_private_ip}" = "$FIRST_SERVER" ]; then
    echo "This is the first controller - ACL tokens already configured during bootstrap"
    exit 0
fi

echo "Waiting for ACL bootstrap to complete on first server..."
while true; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@$${FIRST_SERVER}" "test -f /opt/nomad-consul-token" 2>/dev/null; then
        break
    fi
    sleep 10
done

# Get tokens from the first server
NOMAD_CONSUL_TOKEN="$(ssh -o StrictHostKeyChecking=no "root@$${FIRST_SERVER}" "cat /opt/nomad-consul-token")"

# Configure Consul agent token
consul acl set-agent-token -token="$${NOMAD_CONSUL_TOKEN}" agent "$${NOMAD_CONSUL_TOKEN}"

# Set environment variables for future use
echo "NOMAD_CONSUL_TOKEN=$NOMAD_CONSUL_TOKEN" >> /etc/environment

echo "ACL tokens configured successfully"
