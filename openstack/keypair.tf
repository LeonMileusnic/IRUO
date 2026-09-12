resource "openstack_compute_keypair_v2" "techsprint" {
  name       = "techsprint-keypair"
  public_key = file(pathexpand(var.ssh_public_key_path))
}