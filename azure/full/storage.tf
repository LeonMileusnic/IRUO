resource "azurerm_managed_disk" "developer_data" {
  for_each = local.moodle_instances

  name = "disk-${each.value.developer}-moodle-${each.value.instance_number}-data"

  location = azurerm_resource_group.developer[
    each.value.developer
  ].location

  resource_group_name = azurerm_resource_group.developer[
    each.value.developer
  ].name

  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10

  tags = merge(
    local.common_tags,
    {
      owner    = each.value.developer
      instance = tostring(each.value.instance_number)
    }
  )
}

resource "azurerm_virtual_machine_data_disk_attachment" "developer_data" {
  for_each = local.moodle_instances

  managed_disk_id = azurerm_managed_disk.developer_data[
    each.key
  ].id

  virtual_machine_id = azurerm_linux_virtual_machine.developer[
    each.key
  ].id

  lun     = 0
  caching = "ReadWrite"
}

resource "azurerm_storage_account" "developer" {
  for_each = local.developers

  name                     = "st${each.key}${substr(md5("${var.resource_group_name}-${each.key}"), 0, 8)}"
  resource_group_name      = azurerm_resource_group.developer[each.key].name
  location                 = azurerm_resource_group.developer[each.key].location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = merge(
    local.common_tags,
    {
      owner = each.key
    }
  )
}

resource "azurerm_storage_container" "developer_backups" {
  for_each = local.developers

  name                  = "moodle-backups"
  storage_account_id    = azurerm_storage_account.developer[each.key].id
  container_access_type = "private"
}

resource "azurerm_storage_share" "developer_shared" {
  for_each = local.developers

  name               = "moodle-shared"
  storage_account_id = azurerm_storage_account.developer[each.key].id
  quota              = 5
}