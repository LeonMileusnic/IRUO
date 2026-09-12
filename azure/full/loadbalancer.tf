resource "azurerm_lb" "developer" {
  for_each = local.developers

  name                = "lb-${each.key}-internal"
  location            = azurerm_resource_group.developer[each.key].location
  resource_group_name = azurerm_resource_group.developer[each.key].name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "internal-frontend"
    subnet_id                     = azurerm_subnet.developer[each.key].id
    private_ip_address_allocation = "Dynamic"
  }

  tags = merge(
    local.common_tags,
    {
      owner = each.key
    }
  )
}

resource "azurerm_lb_backend_address_pool" "developer" {
  for_each = local.developers

  name            = "backend-${each.key}-moodle"
  loadbalancer_id = azurerm_lb.developer[each.key].id
}

resource "azurerm_network_interface_backend_address_pool_association" "developer" {
  for_each = local.moodle_instances

  network_interface_id  = azurerm_network_interface.developer[each.key].id
  ip_configuration_name = "internal"

  backend_address_pool_id = azurerm_lb_backend_address_pool.developer[
    each.value.developer
  ].id
}

resource "azurerm_lb_probe" "developer_http" {
  for_each = local.developers

  name                = "http-health"
  loadbalancer_id     = azurerm_lb.developer[each.key].id
  protocol            = "Http"
  port                = 80
  request_path        = "/moodle-health.html"
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "developer_http" {
  for_each = local.developers

  name                           = "http"
  loadbalancer_id                = azurerm_lb.developer[each.key].id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "internal-frontend"

  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.developer[each.key].id
  ]

  probe_id = azurerm_lb_probe.developer_http[each.key].id
}