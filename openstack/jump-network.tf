resource "openstack_compute_interface_attach_v2" "jump_developer" {
  for_each = local.developers

  instance_id = openstack_compute_instance_v2.jump.id
  network_id  = openstack_networking_network_v2.developer[each.key].id
}