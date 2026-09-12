# Outbound Internet access for developer subnets (required so VMs can download
# packages). Previously the VMs relied on Azure's implicit "default outbound
# access", which Microsoft is deprecating for newly created resources and is not
# something a real deployment should depend on. A NAT Gateway gives each
# developer network explicit, reliable egress without exposing any inbound
# public IP on the Moodle VMs themselves.

resource "azurerm_public_ip" "nat" {
  for_each = local.developers

  name                = "pip-nat-${each.key}"
  resource_group_name = azurerm_resource_group.developer[each.key].name
  location            = azurerm_resource_group.developer[each.key].location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(
    local.common_tags,
    {
      owner = each.key
    }
  )
}

resource "azurerm_nat_gateway" "developer" {
  for_each = local.developers

  name                = "nat-${each.key}"
  resource_group_name = azurerm_resource_group.developer[each.key].name
  location            = azurerm_resource_group.developer[each.key].location
  sku_name            = "Standard"

  tags = merge(
    local.common_tags,
    {
      owner = each.key
    }
  )
}

resource "azurerm_nat_gateway_public_ip_association" "developer" {
  for_each = local.developers

  nat_gateway_id       = azurerm_nat_gateway.developer[each.key].id
  public_ip_address_id = azurerm_public_ip.nat[each.key].id
}

resource "azurerm_subnet_nat_gateway_association" "developer" {
  for_each = local.developers

  subnet_id      = azurerm_subnet.developer[each.key].id
  nat_gateway_id = azurerm_nat_gateway.developer[each.key].id
}
