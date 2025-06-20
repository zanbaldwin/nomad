variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name of the SSH key already uploaded to Hetzner Cloud"
  type        = string
  default     = "nomad"
}

variable "region" {
  description = "Hetzner Cloud region"
  type        = string
  default     = "fsn1"
  validation {
    condition     = contains(["fsn1", "nbg1", "hel1", "ash", "hil"], var.region)
    error_message = "Region must be one of: fsn1, nbg1, hel1, ash, hil."
  }
}

variable "server_type_nomad_server" {
  description = "Server type for Nomad servers"
  type        = string
  default     = "cx22"
}

variable "server_type_nomad_client_stateful" {
  description = "Server type for Nomad clients hosting stateful services"
  type        = string
  default     = "cx22"
}

variable "server_type_nomad_client_stateless" {
  description = "Server type for Nomad clients hosting stateless apps"
  type        = string
  default     = "cx22"
}

variable "volume_size_stateful" {
  description = "Size of the volume for stateful data (GB)"
  type        = number
  default     = 5
  validation {
    condition     = var.volume_size_stateful >= 5
    error_message = "Stateful volume size must be at least 5 GB."
  }
}

variable "nomad_server_count" {
  description = "Number of Nomad server nodes (recommended 3 for production HA)"
  type        = number
  default     = 1
  validation {
    condition     = var.nomad_server_count % 2 == 1 && var.nomad_server_count >= 1 && var.nomad_server_count <= 7
    error_message = "Nomad server count must be an odd number between 1 and 7 (recommended: 1 for dev, 3 for production)."
  }
}

variable "nomad_client_stateful_count" {
  description = "Number of Nomad client nodes for stateful services (with attached volumes)"
  type        = number
  default     = 1
}

variable "nomad_client_stateless_count" {
  description = "Number of Nomad client nodes for stateless applications"
  type        = number
  default     = 1
}

variable "project_name" {
  description = "Prefix for resources to identify them"
  type        = string
  default     = "zan-nomad"
}
