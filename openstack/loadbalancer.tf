resource "openstack_lb_loadbalancer_v2" "moodle" {
  for_each = local.developers

  name          = "techsprint-${each.key}-lb"
  vip_subnet_id = openstack_networking_subnet_v2.developer[each.key].id

  tags = [
    "project:techsprint",
    "environment:testing",
    "owner:${each.key}"
  ]
}

resource "openstack_lb_listener_v2" "moodle_http" {
  for_each = local.developers

  name            = "techsprint-${each.key}-http-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.moodle[each.key].id

  tags = [
    "project:techsprint",
    "environment:testing",
    "owner:${each.key}"
  ]
}

resource "openstack_lb_pool_v2" "moodle" {
  for_each = local.developers

  name        = "techsprint-${each.key}-moodle-pool"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.moodle_http[each.key].id

  tags = [
    "project:techsprint",
    "environment:testing",
    "owner:${each.key}"
  ]
}

resource "openstack_lb_member_v2" "moodle" {
  for_each = local.moodle_instances

  name          = "techsprint-${each.value.username}-moodle-${each.value.instance_number}"
  pool_id       = openstack_lb_pool_v2.moodle[each.value.username].id
  address       = each.value.fixed_ip
  protocol_port = 80
  subnet_id     = openstack_networking_subnet_v2.developer[each.value.username].id

  tags = [
    "project:techsprint",
    "environment:testing",
    "owner:${each.value.username}",
    "role:moodle"
  ]
}

resource "openstack_lb_monitor_v2" "moodle" {
  for_each = local.developers

  name        = "techsprint-${each.key}-moodle-health"
  pool_id     = openstack_lb_pool_v2.moodle[each.key].id
  type        = "HTTP"
  delay       = 10
  timeout     = 5
  max_retries = 3
  url_path    = "/moodle-health.html"
}