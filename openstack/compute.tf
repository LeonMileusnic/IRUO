resource "openstack_compute_instance_v2" "jump" {
  name        = "techsprint-jump"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = openstack_compute_keypair_v2.techsprint.name

  security_groups = [
    openstack_networking_secgroup_v2.jump.name
  ]

  metadata = {
    project     = "techsprint"
    environment = "testing"
    role        = "jump-host"
  }

  network {
    uuid = openstack_networking_network_v2.management.id
  }
}

resource "openstack_compute_instance_v2" "moodle" {
  for_each = local.moodle_instances

  name        = "techsprint-${each.value.username}-moodle-${each.value.instance_number}"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = openstack_compute_keypair_v2.techsprint.name

  metadata = {
    project     = "techsprint"
    environment = "testing"
    role        = "moodle"
    owner       = each.value.username
  }

  network {
    port = openstack_networking_port_v2.moodle[each.key].id
  }

  user_data = <<-EOF
    #cloud-config
    runcmd:
      - nmcli con mod "System eth0" ipv4.method manual ipv4.addresses ${each.value.fixed_ip}/24 ipv4.gateway ${each.value.gateway_ip} ipv4.dns "8.8.8.8"
      - nmcli con up "System eth0"
  EOF
}