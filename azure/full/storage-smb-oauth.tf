resource "azapi_update_resource" "developer_storage_smb_oauth" {
  for_each = local.developers

  type        = "Microsoft.Storage/storageAccounts@2025-06-01"
  resource_id = azurerm_storage_account.developer[each.key].id

  body = {
    properties = {
      azureFilesIdentityBasedAuthentication = {
        directoryServiceOptions = "None"

        smbOAuthSettings = {
          isSmbOAuthEnabled = true
        }
      }
    }
  }
}
