resource "azurerm_role_assignment" "developer_blob" {
  for_each = local.moodle_instances

  scope = azurerm_storage_account.developer[
    each.value.developer
  ].id

  role_definition_name = "Storage Blob Data Contributor"

  principal_id = azurerm_linux_virtual_machine.developer[
    each.key
  ].identity[0].principal_id
}

resource "azurerm_role_assignment" "developer_files" {
  for_each = local.moodle_instances

  scope = azurerm_storage_account.developer[
    each.value.developer
  ].id

  role_definition_name = "Storage File Data SMB MI Admin"

  principal_id = azurerm_linux_virtual_machine.developer[
    each.key
  ].identity[0].principal_id
}