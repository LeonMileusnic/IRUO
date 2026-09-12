terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

# Ovaj fajl Terraformu govori koja minimalna Terraform verzija smije izvršavati projekt
# i koje providere projekt treba.

# Terraform CLI
#    |
#    ├── azurerm provider
#    └── azapi provider
#           |
#        Azure API
#           |
#      Azure resursi