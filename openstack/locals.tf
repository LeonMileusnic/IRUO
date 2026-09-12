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

  developer_usernames = sort(keys(local.developers))

  developer_networks = {
    for index, username in local.developer_usernames :
    username => cidrsubnet("10.10.0.0/16", 8, index + 1)
  }

  management_network = "10.10.100.0/24"

  moodle_instances = merge([
    for username, user in local.developers : {
      for instance_number in range(1, 3) :
      "${username}-${instance_number}" => {
        username        = username
        instance_number = instance_number
        fixed_ip        = cidrhost(local.developer_networks[username], 10 + instance_number)
        gateway_ip      = cidrhost(local.developer_networks[username], 1)
      }
    }
  ]...)
}