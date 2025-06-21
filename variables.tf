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
