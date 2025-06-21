# Provisioning Templates

Cloud Init scripts for provisioning a base Linux image into a functioning **Nomad** + **Consul** node server.

## Shared

1. Install Docker
2. Install Consul (and setup as SystemD service)
3. Install Nomad (and setup as SystemD service)

### All Controller Nodes

1. Write Consul configuration file to disk
2. Write Nomad configuration file to disk

#### First Controller Node

1. Bootstrap ACL tokens for Consul + Nomad

### All Client Nodes

1. Write Consul configuration file to disk
2. Write Nomad configuration file to disk
3. Join existing cluster using bootstrapped ACL tokens
