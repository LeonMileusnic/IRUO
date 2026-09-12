output "jump_host_floating_ip" {
  description = "Public floating IP address of the Jump Host"
  value       = openstack_networking_floatingip_v2.jump.address
}

output "jump_host_management_ip" {
  description = "Private management IP address of the Jump Host"
  value       = openstack_compute_instance_v2.jump.access_ip_v4
}

output "moodle_fixed_ips" {
  description = "Static private IP addresses of Moodle instances"

  value = {
    for key, instance in local.moodle_instances :
    key => instance.fixed_ip
  }
}

output "moodle_instances" {
  description = "Moodle instance information for Ansible inventory"

  value = {
    for key, instance in local.moodle_instances :
    key => {
      username        = instance.username
      instance_number = instance.instance_number
      ip_address      = instance.fixed_ip
    }
  }
}

output "developer_networks" {
  description = "Developer network CIDRs"

  value = local.developer_networks
}

output "moodle_load_balancer_vips" {
  description = "Private VIP addresses of the per-developer Moodle load balancers"

  value = {
    for username, lb in openstack_lb_loadbalancer_v2.moodle :
    username => lb.vip_address
  }
}

output "developer_backup_containers" {
  description = "Swift backup container name for each developer"

  value = {
    for username, container in openstack_objectstorage_container_v1.developer_backup :
    username => container.name
  }
}

output "developer_application_credentials" {
  description = "Scoped application credential (id/secret) used to auto-mount each developer's own Swift container and manage their own VMs"
  sensitive   = true

  value = {
    for username, cred in openstack_identity_application_credential_v3.developer :
    username => {
      id     = cred.id
      secret = cred.secret
    }
  }
}