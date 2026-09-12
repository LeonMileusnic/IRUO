resource "openstack_networking_secgroup_v2" "jump" {
  name        = "techsprint-jump-sg"
  description = "Security group for TechSprint Jump Host"

  tags = [
    "project:techsprint",
    "environment:testing",
    "role:jump-host"
  ]
}

resource "openstack_networking_secgroup_rule_v2" "jump_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.admin_source_cidr
  security_group_id = openstack_networking_secgroup_v2.jump.id
}

resource "openstack_networking_secgroup_v2" "moodle" {
  for_each = local.developers

  name        = "techsprint-${each.key}-moodle-sg"
  description = "Security group for ${each.key} Moodle servers"

  tags = [
    "project:techsprint",
    "environment:testing",
    "owner:${each.key}",
    "role:moodle"
  ]
}

resource "openstack_networking_secgroup_rule_v2" "moodle_ssh" {
  for_each = local.developers

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = local.developer_networks[each.key]
  security_group_id = openstack_networking_secgroup_v2.moodle[each.key].id
}

resource "openstack_networking_secgroup_rule_v2" "moodle_http" {
  for_each = local.developers

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = local.developer_networks[each.key]
  security_group_id = openstack_networking_secgroup_v2.moodle[each.key].id
}