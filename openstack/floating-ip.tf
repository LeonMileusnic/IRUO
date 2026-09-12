resource "openstack_networking_floatingip_v2" "jump" {
  pool = var.external_network_name

  tags = [
    "project:techsprint",
    "environment:testing",
    "role:jump-host"
  ]
}

data "openstack_networking_port_v2" "jump" {
  device_id  = openstack_compute_instance_v2.jump.id
  network_id = openstack_networking_network_v2.management.id
}

resource "openstack_networking_floatingip_associate_v2" "jump" {
  floating_ip = openstack_networking_floatingip_v2.jump.address
  port_id     = data.openstack_networking_port_v2.jump.id
}