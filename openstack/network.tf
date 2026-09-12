data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

resource "openstack_networking_network_v2" "developer" {
  for_each = local.developers

  name           = "techsprint-${each.key}-network"
  admin_state_up = true

  tags = [
    "project:techsprint",
    "environment:testing",
    "owner:${each.key}"
  ]
}

resource "openstack_networking_subnet_v2" "developer" {
  for_each = local.developers

  name       = "techsprint-${each.key}-subnet"
  network_id = openstack_networking_network_v2.developer[each.key].id
  cidr       = local.developer_networks[each.key]
  ip_version = 4

  dns_nameservers = [
    "8.8.8.8"
  ]

  tags = [
    "project:techsprint",
    "environment:testing",
    "owner:${each.key}"
  ]
}

resource "openstack_networking_router_v2" "developer" {
  for_each = local.developers

  name                = "techsprint-${each.key}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id

  tags = [
    "project:techsprint",
    "environment:testing",
    "owner:${each.key}"
  ]
}

resource "openstack_networking_router_interface_v2" "developer" {
  for_each = local.developers

  router_id = openstack_networking_router_v2.developer[each.key].id
  subnet_id = openstack_networking_subnet_v2.developer[each.key].id
}

resource "openstack_networking_network_v2" "management" {
  name           = "techsprint-management-network"
  admin_state_up = true

  tags = [
    "project:techsprint",
    "environment:testing",
    "role:management"
  ]
}

resource "openstack_networking_subnet_v2" "management" {
  name       = "techsprint-management-subnet"
  network_id = openstack_networking_network_v2.management.id
  cidr       = local.management_network
  ip_version = 4

  dns_nameservers = [
    "8.8.8.8"
  ]

  tags = [
    "project:techsprint",
    "environment:testing",
    "role:management"
  ]
}

resource "openstack_networking_router_v2" "management" {
  name                = "techsprint-management-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id

  tags = [
    "project:techsprint",
    "environment:testing",
    "role:management"
  ]
}

resource "openstack_networking_router_interface_v2" "management" {
  router_id = openstack_networking_router_v2.management.id
  subnet_id = openstack_networking_subnet_v2.management.id
}