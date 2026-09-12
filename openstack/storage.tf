resource "openstack_blockstorage_volume_v3" "moodle_data" {
  for_each = local.moodle_instances

  name = "techsprint-${each.value.username}-moodle-${each.value.instance_number}-data"
  size = 10

  metadata = {
    project     = "techsprint"
    environment = "testing"
    role        = "moodle-data"
    owner       = each.value.username
  }
}

resource "openstack_compute_volume_attach_v2" "moodle_data" {
  for_each = local.moodle_instances

  instance_id = openstack_compute_instance_v2.moodle[each.key].id
  volume_id   = openstack_blockstorage_volume_v3.moodle_data[each.key].id
}