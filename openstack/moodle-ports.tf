resource "openstack_networking_port_v2" "moodle" {
  for_each = local.moodle_instances

  name       = "techsprint-${each.value.username}-moodle-${each.value.instance_number}-port"
  network_id = openstack_networking_network_v2.developer[each.value.username].id

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.developer[each.value.username].id
    ip_address = each.value.fixed_ip
  }

  security_group_ids = [
    openstack_networking_secgroup_v2.moodle[each.value.username].id
  ]

  tags = [
    "project:techsprint",
    "environment:testing",
    "owner:${each.value.username}",
    "role:moodle",
    "instance:${each.value.instance_number}"
  ]
}