variable "region" {
  description = "OpenStack region"
  type        = string
  default     = "regionOne"
}

variable "external_network_name" {
  description = "External OpenStack network used for router gateway and floating IPs"
  type        = string
  default     = "provider-datacentre"
}

variable "image_name" {
  description = "Image used for TechSprint virtual machines"
  type        = string
  default     = "rhel8"
}

variable "flavor_name" {
  description = "Flavor used for TechSprint virtual machines. Must provide at least 2 vCPU / 4 GB RAM per the task requirement. The 'default' Red Hat Academy flavor only provides 2 GB RAM (see docs/openstack.md) - on any other OpenStack, set this to a real >=4GB flavor, e.g. 'm1.medium'."
  type        = string
  default     = "default"
}

variable "users_csv_path" {
  description = "Path to the CSV file containing TechSprint users"
  type        = string
  default     = "../data/users.csv"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used for TechSprint instances"
  type        = string
  default     = "~/.ssh/techsprint.pub"
}

variable "admin_source_cidr" {
  description = "CIDR allowed to access the Jump Host over SSH. Must be an explicit administrator range, not the whole Internet."
  type        = string

  validation {
    condition     = var.admin_source_cidr != "0.0.0.0/0" && var.admin_source_cidr != "*"
    error_message = "admin_source_cidr must not allow the entire Internet (0.0.0.0/0). Set it to your real administrator IP range, e.g. TF_VAR_admin_source_cidr=\"203.0.113.10/32\"."
  }
}