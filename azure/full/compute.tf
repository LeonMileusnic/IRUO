resource "azurerm_network_interface" "developer" {
  for_each = local.moodle_instances

  name                = "nic-${each.value.developer}-${each.value.instance_number}"
  location            = azurerm_resource_group.developer[each.value.developer].location
  resource_group_name = azurerm_resource_group.developer[each.value.developer].name

  tags = merge(
    local.common_tags,
    {
      owner    = each.value.developer
      instance = tostring(each.value.instance_number)
    }
  )

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.developer[each.value.developer].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "developer" {
  for_each = local.moodle_instances

  depends_on = [
    azapi_update_resource.developer_storage_smb_oauth,
    azurerm_marketplace_agreement.rocky
  ]

  name                = "vm-${each.value.developer}-moodle-${each.value.instance_number}"
  resource_group_name = azurerm_resource_group.developer[each.value.developer].name
  location            = azurerm_resource_group.developer[each.value.developer].location
  size                = var.vm_size
  admin_username      = var.admin_username

  tags = merge(
    local.common_tags,
    {
      owner    = each.value.developer
      instance = tostring(each.value.instance_number)
    }
  )

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(
    templatefile("${path.module}/scripts/moodle-bootstrap.sh", {
      moodle_db_password   = var.moodle_db_password
      storage_account_name = azurerm_storage_account.developer[each.value.developer].name
      blob_container_name  = azurerm_storage_container.developer_backups[each.value.developer].name
      file_share_name      = azurerm_storage_share.developer_shared[each.value.developer].name
      moodle_url           = "http://${azurerm_lb.developer[each.value.developer].private_ip_address}"
    })
  )

  network_interface_ids = [
    azurerm_network_interface.developer[each.key].id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Rocky Linux (Azure Marketplace), as required by the task instead of Ubuntu.
  source_image_reference {
    publisher = local.rocky_image.publisher
    offer     = local.rocky_image.offer
    sku       = local.rocky_image.sku
    version   = "latest"
  }

  plan {
    name      = local.rocky_image.sku
    publisher = local.rocky_image.publisher
    product   = local.rocky_image.offer
  }
}

resource "azurerm_public_ip" "jump" {
  name                = "pip-jump"
  resource_group_name = azurerm_resource_group.techsprint.name
  location            = azurerm_resource_group.techsprint.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

resource "azurerm_network_interface" "jump" {
  name                = "nic-jump"
  location            = azurerm_resource_group.techsprint.location
  resource_group_name = azurerm_resource_group.techsprint.name

  tags = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jump.id
  }
}

resource "azurerm_linux_virtual_machine" "jump" {
  depends_on = [
    azurerm_marketplace_agreement.rocky
  ]

  name                = "vm-techsprint-jump"
  resource_group_name = azurerm_resource_group.techsprint.name
  location            = azurerm_resource_group.techsprint.location
  size                = var.vm_size
  admin_username      = var.admin_username

  tags = local.common_tags

  network_interface_ids = [
    azurerm_network_interface.jump.id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Rocky Linux (Azure Marketplace), as required by the task instead of Ubuntu.
  source_image_reference {
    publisher = local.rocky_image.publisher
    offer     = local.rocky_image.offer
    sku       = local.rocky_image.sku
    version   = "latest"
  }

  plan {
    name      = local.rocky_image.sku
    publisher = local.rocky_image.publisher
    product   = local.rocky_image.offer
  }
}