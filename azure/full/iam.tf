data "azurerm_subscription" "current" {}

# Auto-resolve each CSV user's Entra object ID from their username, so RBAC is
# wired up automatically instead of requiring a manual object-ID lookup/copy-paste
# step after every deployment. Requires the developer/lead to already exist in
# Entra ID as <username>@var.entra_domain. If entra_domain is left empty, the
# explicit developer_principal_ids/lead_principal_id maps are used instead.
data "azuread_user" "developer" {
  for_each = var.entra_domain != "" ? local.developers : {}

  user_principal_name = "${each.key}@${var.entra_domain}"
}

data "azuread_user" "lead" {
  for_each = var.entra_domain != "" ? local.leads : {}

  user_principal_name = "${each.key}@${var.entra_domain}"
}

locals {
  resolved_developer_principal_ids = merge(
    var.developer_principal_ids,
    { for username, user in data.azuread_user.developer : username => user.object_id }
  )

  resolved_lead_principal_id = length(data.azuread_user.lead) > 0 ? values(data.azuread_user.lead)[0].object_id : var.lead_principal_id
}

resource "azurerm_role_definition" "vm_power_operator" {
  name  = "TechSprint VM Power Operator"
  scope = data.azurerm_subscription.current.id

  description = "Allows TechSprint users to read and control the power state of virtual machines."

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/instanceView/read",
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/powerOff/action",
      "Microsoft.Compute/virtualMachines/deallocate/action"
    ]

    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id
  ]
}

resource "azurerm_role_assignment" "developer_vm" {
  for_each = {
    for username, principal_id in local.resolved_developer_principal_ids :
    username => principal_id
    if contains(keys(local.developers), username)
  }

  scope              = azurerm_resource_group.developer[each.key].id
  role_definition_id = azurerm_role_definition.vm_power_operator.role_definition_resource_id
  principal_id       = each.value
}

resource "azurerm_role_assignment" "lead_vm" {
  for_each = local.resolved_lead_principal_id != "" ? local.developers : {}

  scope              = azurerm_resource_group.developer[each.key].id
  role_definition_id = azurerm_role_definition.vm_power_operator.role_definition_resource_id
  principal_id       = local.resolved_lead_principal_id
}