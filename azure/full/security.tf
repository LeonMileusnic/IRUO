resource "azurerm_network_security_group" "developer" {
  for_each = local.developers

  name                = "nsg-${each.key}"
  location            = azurerm_resource_group.developer[each.key].location
  resource_group_name = azurerm_resource_group.developer[each.key].name

  tags = merge(
    local.common_tags,
    {
      owner = each.key
    }
  )

  security_rule {
    name                   = "Allow-SSH-From-Management"
    priority               = 100
    direction              = "Inbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "*"
    destination_port_range = "22"
    source_address_prefix  = local.management_subnet

    destination_application_security_group_ids = [
      azurerm_application_security_group.developer[each.key].id
    ]
  }

  # Scoped to the developer's own VNet: the internal Load Balancer frontend lives
  # in this same address space, and no entity outside it should ever reach the
  # Moodle VMs directly (there is no public IP in front of them). Previously this
  # was source_address_prefix = "*", which is unnecessarily broad even though the
  # LB has no public IP today, and it contradicted the "no direct public access"
  # requirement in spirit.
  security_rule {
    name                   = "Allow-HTTP-To-Moodle"
    priority               = 110
    direction              = "Inbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "*"
    destination_port_range = "80"
    source_address_prefix  = local.developer_vnets[each.key]

    destination_application_security_group_ids = [
      azurerm_application_security_group.developer[each.key].id
    ]
  }

  security_rule {
    name                   = "Allow-HTTPS-To-Moodle"
    priority               = 120
    direction              = "Inbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "*"
    destination_port_range = "443"
    source_address_prefix  = local.developer_vnets[each.key]

    destination_application_security_group_ids = [
      azurerm_application_security_group.developer[each.key].id
    ]
  }
}

resource "azurerm_network_security_group" "management" {
  name                = "nsg-management"
  location            = azurerm_resource_group.techsprint.location
  resource_group_name = azurerm_resource_group.techsprint.name

  tags = local.common_tags

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_source_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "developer" {
  for_each = local.developers

  subnet_id                 = azurerm_subnet.developer[each.key].id
  network_security_group_id = azurerm_network_security_group.developer[each.key].id
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}