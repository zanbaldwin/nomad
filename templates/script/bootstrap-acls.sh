#!/bin/bash
# This is a cloud-init template file. Bash "dollar-brace" variables should be double-dollar escaped `$$`.
set -e

function bootstrap_consul_acl {
    if ! consul acl bootstrap -format=json >'/tmp/consul-bootstrap.json'; then
        echo >&2 'Consul ACL already bootstrapped (or failed).'
        if [ -f '/opt/consul-root-token' ]; then
            cat '/opt/consul-root-token'
            return 0
        fi
        return 1
    fi

    export CONSUL_HTTP_TOKEN="$(cat '/tmp/consul-bootstrap.json' | jq -r '.SecretID')"
    echo "$${CONSUL_HTTP_TOKEN}" >'/opt/consul-root-token'
    echo "CONSUL_HTTP_TOKEN=$${CONSUL_HTTP_TOKEN}" >>'/etc/environment'
    echo "$${CONSUL_HTTP_TOKEN}"
}

function consul_policy {
    export CONSUL_HTTP_TOKEN="$${1:-$$(cat '/opt/consul-root-token')}"
    # Create Nomad agent policy for Consul integration
    POLICY='agent_prefix "" { policy = "write" }
            node_prefix "" { policy = "write" }
            service_prefix "" { policy = "read" }
            acl = "read"'
    if ! consul acl policy create -name "nomad-agent" -description "Nomad Agent Policy" -rules "$${POLICY}"; then
        echo >&2 'Consul policy already bootstrapped (or failed).'
    fi
    # Create token for Nomad agents
    consul acl token create -description "Nomad Agent Token" -policy-name "nomad-agent" -format=json >'/tmp/nomad-consul-token.json'

    export NOMAD_CONSUL_TOKEN="$$(cat '/tmp/nomad-consul-token.json' | jq -r '.SecretID')"
    echo "$${NOMAD_CONSUL_TOKEN}" >'/opt/nomad-consul-token'
    echo "NOMAD_CONSUL_TOKEN=$${NOMAD_CONSUL_TOKEN}" >>'/etc/environment'
    echo "$${NOMAD_CONSUL_TOKEN}"
}

function bootstrap_nomad_acl {
    if ! nomad acl bootstrap -json >'/tmp/nomad-bootstrap.json'; then
        echo >&2 'Nomad ACL already bootstrapped (or failed).'
        if [ -f '/opt/nomad-root-token' ]; then
            cat '/opt/nomad-root-token'
            return 0
        fi
        return 1
    fi

    export NOMAD_TOKEN="$$(cat '/tmp/nomad-bootstrap.json' | jq -r '.SecretID')"
    echo "$${NOMAD_TOKEN}" >'/opt/nomad-root-token'
    echo "NOMAD_TOKEN=$${NOMAD_TOKEN}" >>'/etc/environment'
    echo "$${NOMAD_TOKEN}"
}


# Bootstrap Consul+Nomad ACLs (only run on first server)
if [ "${node_private_ip}" = "$(echo '${consul_controller_ips}' | jq -r '.[0]')" ]; then
    echo "Waiting for Consul to be ready on local machine..."
    while ! curl -fsSL "http://127.0.0.1:8500/v1/status/leader" >'/dev/null' 2>&1; do
        sleep 5
    done
    CONSUL_HTTP_TOKEN="$$(bootstrap_consul_acl)"
    NOMAD_CONSUL_TOKEN="$$(consul_policy "$${CONSUL_HTTP_TOKEN}")"

    echo "Waiting for Nomad to be ready on local machine..."
    while ! curl -fsSL "http://127.0.0.1:4646/v1/status/leader" >'/dev/null' 2>&1; do
        sleep 5
    done
    NOMAD_TOKEN="$$(bootstrap_nomad_acl)"

    chmod 0600 /opt/*-token
fi
