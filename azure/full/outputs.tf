output "developer_resource_groups" {
  description = "Resource group created for each developer"
  value = {
    for username, rg in azurerm_resource_group.developer :
    username => rg.name
  }
}

output "developer_virtual_networks" {
  description = "Virtual network created for each developer"
  value = {
    for username, vnet in azurerm_virtual_network.developer :
    username => vnet.name
  }
}

output "moodle_virtual_machines" {
  description = "Moodle virtual machines created for each developer"
  value = {
    for instance, vm in azurerm_linux_virtual_machine.developer :
    instance => vm.name
  }
}

output "developer_load_balancer_addresses" {
  description = "Private IP address of each developer Moodle load balancer"
  value = {
    for username, lb in azurerm_lb.developer :
    username => lb.private_ip_address
  }
}

output "developer_storage_accounts" {
  description = "Storage account created for each developer"
  value = {
    for username, storage in azurerm_storage_account.developer :
    username => storage.name
  }
}

output "jump_host_public_ip" {
  description = "Public IP address of the TechSprint Jump Host"
  value       = azurerm_public_ip.jump.ip_address
}
