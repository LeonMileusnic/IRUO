resource "azurerm_resource_group" "techsprint" {
  name     = var.resource_group_name
  location = var.location

  tags = local.common_tags
}

resource "azurerm_resource_group" "developer" {
  for_each = local.developers

  name     = "${var.resource_group_name}-${each.key}"
  location = var.location

  tags = merge(
    local.common_tags,
    {
      owner = each.key
    }
  )
}