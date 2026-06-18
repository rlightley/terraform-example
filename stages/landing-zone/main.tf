terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

module "landing_zone" {
  source = "../../modules/landing-zone"

  workload                         = var.workload
  location                         = var.location
  location_short                   = var.location_short
  environment                      = var.environment
  vnet_address_space               = var.vnet_address_space
  subnets                          = var.subnets
  key_vault_sku                    = var.key_vault_sku
  key_vault_network_default_action = var.key_vault_network_default_action
  log_analytics_sku                = var.log_analytics_sku
  log_retention_days               = var.log_retention_days
  role_assignments                 = var.role_assignments
  allowed_locations                = var.allowed_locations
  tags                             = var.tags
}
