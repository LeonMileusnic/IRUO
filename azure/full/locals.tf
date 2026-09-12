locals {
  # The task requires a "ime;prezime;rola" (semicolon separated) CSV. Terraform's
  # csvdecode() only understands commas per RFC4180, so the delimiter is normalized
  # before decoding. Username and role are then derived from the raw columns.
  raw_users = csvdecode(replace(file(var.users_csv_path), ";", ","))

  users = [
    for user in local.raw_users : merge(user, {
      username = lower(trimspace(user.ime))
      role     = trimspace(user.rola) == "devops_lead" ? "lead" : "developer"
    })
  ]

  developers = {
    for user in local.users :
    user.username => user
    if user.role == "developer"
  }

  leads = {
    for user in local.users :
    user.username => user
    if user.role == "lead"
  }

  developer_vnets = {
    for index, username in sort(keys(local.developers)) :
    username => cidrsubnet(var.vnet_address_space[0], 8, index + 1)
  }

  developer_subnets = {
    for username, cidr in local.developer_vnets :
    username => cidrsubnet(cidr, 4, 0)
  }

  moodle_instances = merge([
    for username in sort(keys(local.developers)) : {
      for instance_number in [1, 2] :
      "${username}-${instance_number}" => {
        developer       = username
        instance_number = instance_number
      }
    }
  ]...)

  management_vnet   = "10.10.100.0/24"
  management_subnet = "10.10.100.0/25"

  common_tags = {
    project     = "techsprint"
    environment = "testing"
  }
}