# Per-developer VM power management, actually enforced (not just documented).
#
# Why application credentials instead of Keystone projects/roles:
# docs/openstack-iam-rbac.md already documents, with evidence (HTTP 403 on
# identity:list_services), that the Red Hat Academy student account has no
# administrative Keystone permissions. It cannot create projects, users, groups
# or roles, so openstack_identity_project_v3/openstack_identity_role_v3 resources
# would simply fail to apply in this environment - adding them would look like a
# fix while actually being untestable/broken here.
#
# Also, even with admin rights, Keystone role assignments are project-scoped,
# not per-VM: since every developer's instances live in the one shared Academy
# project, a Keystone role could not by itself express "only this developer's
# own VMs" - that boundary has to be enforced at the resource level.
#
# Application credentials solve both problems: any regular user can create their
# own (self-service, not an admin action, so it works on Academy), and each one
# can carry access_rules that restrict it to specific API paths - here, POST
# .../servers/{id}/action and GET .../servers/{id} for exactly that developer's
# two VMs, plus read/write on exactly that developer's own Swift container. One
# scoped credential is generated per developer (and one broader one for the
# DevOps Lead) and handed to that person instead of the shared project login.
#
# In a real OpenStack deployment with administrative Keystone access, the
# project-per-developer design in docs/openstack-iam-rbac.md remains the
# stronger production recommendation; this is the mechanism that is actually
# deployable under the constraints of this specific environment.

data "openstack_identity_auth_scope_v3" "current" {
  name = "current"
}

resource "openstack_identity_application_credential_v3" "developer" {
  for_each = local.developers

  name        = "techsprint-${each.key}-vm-power"
  description = "Scoped credential letting ${each.key} manage only their own Moodle VMs and their own Swift backup container"

  access_rules {
    path    = "/v2.1/servers/${openstack_compute_instance_v2.moodle["${each.key}-1"].id}"
    method  = "GET"
    service = "compute"
  }

  access_rules {
    path    = "/v2.1/servers/${openstack_compute_instance_v2.moodle["${each.key}-1"].id}/action"
    method  = "POST"
    service = "compute"
  }

  access_rules {
    path    = "/v2.1/servers/${openstack_compute_instance_v2.moodle["${each.key}-2"].id}"
    method  = "GET"
    service = "compute"
  }

  access_rules {
    path    = "/v2.1/servers/${openstack_compute_instance_v2.moodle["${each.key}-2"].id}/action"
    method  = "POST"
    service = "compute"
  }

  access_rules {
    path    = "/v1/AUTH_${data.openstack_identity_auth_scope_v3.current.project_id}/${openstack_objectstorage_container_v1.developer_backup[each.key].name}/*"
    method  = "GET"
    service = "object-store"
  }

  access_rules {
    path    = "/v1/AUTH_${data.openstack_identity_auth_scope_v3.current.project_id}/${openstack_objectstorage_container_v1.developer_backup[each.key].name}/*"
    method  = "PUT"
    service = "object-store"
  }
}

resource "openstack_identity_application_credential_v3" "lead" {
  for_each = local.leads

  name        = "techsprint-${each.key}-vm-power-all"
  description = "Scoped credential letting DevOps Lead ${each.key} manage all developer Moodle VMs"

  dynamic "access_rules" {
    for_each = openstack_compute_instance_v2.moodle
    content {
      path    = "/v2.1/servers/${access_rules.value.id}"
      method  = "GET"
      service = "compute"
    }
  }

  dynamic "access_rules" {
    for_each = openstack_compute_instance_v2.moodle
    content {
      path    = "/v2.1/servers/${access_rules.value.id}/action"
      method  = "POST"
      service = "compute"
    }
  }
}
