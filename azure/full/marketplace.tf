# Rocky Linux replaces the previous Ubuntu image: the task explicitly requires
# Rocky Linux / CentOS Stream / a cloud-specialized distribution, not Ubuntu.
# The official Rocky Linux Azure Marketplace listing is plan-based, so the
# subscription must accept its legal terms once before any VM using it can be
# created (azurerm_linux_virtual_machine's "plan" block alone does not do this).

locals {
  rocky_image = {
    publisher = "erockyenterprisesoftwarefoundationinc1653071250513"
    offer     = "rockylinux-x86_64"
    sku       = "rockylinux-x86_64"
  }
}

resource "azurerm_marketplace_agreement" "rocky" {
  publisher = local.rocky_image.publisher
  offer     = local.rocky_image.offer
  plan      = local.rocky_image.sku
}
