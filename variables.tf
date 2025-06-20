variable "hcloud_token" {
    description = "Hetzner Cloud API Token"
    type        = string
    sensitive   = true
}

variable "ssh_key_name" {
    description = "Name of the SSH key already uploaded to Hetzner Cloud"
    type        = string
    default     = "my-ssh-key" # <<< Replace with your actual SSH key name in Hetzner Cloud
}

variable "region" {
    description = "Hetzner Cloud region"
    type        = string
    default     = "fsn1" # Falkenstein
}

variable "server_type_nomad_server" {
    description = "Server type for Nomad servers"
    type        = string
    default     = "cx21" # 2 vCPU, 4GB RAM - good for small server cluster
}

variable "server_type_nomad_client_stateful" {
    description = "Server type for Nomad clients hosting stateful services"
    type        = string
    default     = "ccx12" # 2 vCPU, 16GB RAM - more robust for DB/storage
}

variable "server_type_nomad_client_stateless" {
    description = "Server type for Nomad clients hosting stateless apps"
    type        = string
    default     = "cx21" # 2 vCPU, 4GB RAM - good starting point
}

variable "volume_size_postgres" {
    description = "Size of the volume for PostgreSQL data (GB)"
    type        = number
    default     = 50
}

variable "volume_size_garage" {
    description = "Size of the volume for Garage data (GB)"
    type        = number
    default     = 100
}

variable "nomad_server_count" {
    description = "Number of Nomad server nodes (recommended 3 for production HA)"
    type        = number
    default     = 3
}

variable "nomad_client_stateful_count" {
    description = "Number of Nomad client nodes for stateful services (with attached volumes)"
    type        = number
    default     = 2 # At least 2 for basic HA/replication capability for stateful apps
}

variable "nomad_client_stateless_count" {
    description = "Number of Nomad client nodes for stateless applications"
    type        = number
    default     = 3
}

variable "project_name" {
    description = "Prefix for resources to identify them"
    type        = string
    default     = "my-nomad-cluster"
}
