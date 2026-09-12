resource "azurerm_virtual_network" "developer" {
  for_each = local.developers

  name                = "vnet-${each.key}"
  address_space       = [local.developer_vnets[each.key]]
  location            = azurerm_resource_group.developer[each.key].location
  resource_group_name = azurerm_resource_group.developer[each.key].name

  tags = merge(
    local.common_tags,
    {
      owner = each.key
    }
  )
}

resource "azurerm_subnet" "developer" {
  for_each = local.developers

  name                 = "snet-${each.key}"
  resource_group_name  = azurerm_resource_group.developer[each.key].name
  virtual_network_name = azurerm_virtual_network.developer[each.key].name
  address_prefixes     = [local.developer_subnets[each.key]]
}

resource "azurerm_virtual_network" "management" {
  name                = "vnet-management"
  address_space       = [local.management_vnet]
  location            = azurerm_resource_group.techsprint.location
  resource_group_name = azurerm_resource_group.techsprint.name

  tags = local.common_tags
}

resource "azurerm_subnet" "management" {
  name                 = "snet-management"
  resource_group_name  = azurerm_resource_group.techsprint.name
  virtual_network_name = azurerm_virtual_network.management.name
  address_prefixes     = [local.management_subnet]
}

resource "azurerm_virtual_network_peering" "management_to_developer" {
  for_each = local.developers

  name                      = "peer-management-to-${each.key}"
  resource_group_name       = azurerm_resource_group.techsprint.name
  virtual_network_name      = azurerm_virtual_network.management.name
  remote_virtual_network_id = azurerm_virtual_network.developer[each.key].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
}

resource "azurerm_virtual_network_peering" "developer_to_management" {
  for_each = local.developers

  name                      = "peer-${each.key}-to-management"
  resource_group_name       = azurerm_resource_group.developer[each.key].name
  virtual_network_name      = azurerm_virtual_network.developer[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.management.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
}