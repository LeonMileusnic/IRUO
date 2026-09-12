variable "location" {
  description = "Azure region used for TechSprint resources"
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Name of the main TechSprint resource group"
  type        = string
  default     = "rg-techsprint"
}

variable "users_csv_path" {
  description = "Path to the CSV file containing TechSprint users"
  type        = string
  default     = "../../data/users.csv"
}

variable "vnet_address_space" {
  description = "Address space for the TechSprint virtual network"
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "admin_username" {
  description = "Administrator username for Linux virtual machines"
  type        = string
  default     = "techadmin"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used for virtual machines"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "vm_size" {
  description = "Azure VM size used for developer environments"
  type        = string
  default     = "Standard_B2s"
}

variable "developer_principal_ids" {
  description = "Map of developer usernames to Microsoft Entra principal object IDs"
  type        = map(string)
  default     = {}
}

variable "lead_principal_id" {
  description = "Microsoft Entra principal object ID for the TechSprint lead"
  type        = string
  default     = ""
}

variable "moodle_db_password" {
  description = "Password for the local Moodle database user"
  type        = string
  sensitive   = true
}

variable "admin_source_cidr" {
  description = "CIDR allowed to access the Jump Host over SSH. Must be an explicit administrator range, not the whole Internet."
  type        = string

  validation {
    condition     = var.admin_source_cidr != "0.0.0.0/0" && var.admin_source_cidr != "*"
    error_message = "admin_source_cidr must not allow the entire Internet (0.0.0.0/0). Set it to your real administrator IP range, e.g. TF_VAR_admin_source_cidr=\"203.0.113.10/32\"."
  }
}

variable "entra_domain" {
  description = "Microsoft Entra UPN domain (e.g. techsprint.onmicrosoft.com) used to auto-resolve developer/lead object IDs from their CSV username (username@entra_domain). Leave empty to skip automatic RBAC assignment and rely only on developer_principal_ids/lead_principal_id."
  type        = string
  default     = ""
}