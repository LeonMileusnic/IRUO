resource "openstack_objectstorage_container_v1" "developer_backup" {
  for_each = local.developers

  name = "techsprint-${each.key}-moodle-backups"

  metadata = {
    project     = "techsprint"
    environment = "testing"
    owner       = each.key
    purpose     = "moodle-backups"
  }
}