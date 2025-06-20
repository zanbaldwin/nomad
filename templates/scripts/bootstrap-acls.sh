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