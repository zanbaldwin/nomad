variable "organization_name" {
  description = "Organization Name"
  type        = string
  default     = "my-company"
}

variable "project_name" {
  description = "Namespace Prefix for Resources"
  type        = string
  default     = "my-nomad-cluster"
}

variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name of SSH Key (already uploaded to Hetzner Cloud)"
  type        = string
  # Replace with your actual SSH key name in Hetzner Cloud
  default = "my-ssh-key"
}

variable "region" {
  description = "Hetzner Cloud region"
  type        = string
  default     = "fsn1"
  validation {
    condition     = contains(["fsn1", "nbg1", "hel1"], var.region)
    error_message = "Region must be one within `eu-central` network zone: fsn1, nbg1, hel1."
  }
}

variable "server_base_image" {
  description = "Base image to use for all servers"
  type        = string
  default     = "ubuntu-24.04"
}

variable "server_controller_type" {
  description = "Server type for Nomad controller node servers"
  type        = string
  default     = "cx22"
}

variable "server_controller_count" {
  description = "Number of Nomad controller nodes (recommended 3 for production HA)"
  type        = number
  default     = 1
  validation {
    condition     = var.server_controller_count % 2 == 1 && var.server_controller_count >= 1 && var.server_controller_count <= 7
    error_message = "Nomad controller count must be an odd number between 1 and 7 (recommended: 1 for dev, 3 for production)."
  }
}

variable "server_client_type" {
  description = "Server type for Nomad client node servers"
  type        = string
  default     = "cx22"
}

variable "server_client_count" {
  description = "Number of Nomad client nodes"
  type        = number
  default     = 1
}
