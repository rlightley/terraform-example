terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.50"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

data "terraform_remote_state" "landing_zone" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state_backend_resource_group_name
    storage_account_name = var.state_backend_storage_account_name
    container_name       = var.state_backend_container_name
    key                  = var.landing_zone_state_key
  }
}

module "application" {
  source = "../../modules/application"

  workload                   = var.workload
  location                   = var.location
  location_short             = var.location_short
  environment                = var.environment
  app_service_plan_sku_name  = var.app_service_plan_sku_name
  app_stack                  = var.app_stack
  sql_database_sku_name      = var.sql_database_sku_name
  sql_aad_admin_login        = var.sql_aad_admin_login
  vnet_integration_subnet_id = data.terraform_remote_state.landing_zone.outputs.subnet_ids[var.vnet_integration_subnet_name]
  log_analytics_workspace_id = data.terraform_remote_state.landing_zone.outputs.log_analytics_workspace_id
  key_vault_id               = data.terraform_remote_state.landing_zone.outputs.key_vault_id
  tags                       = var.tags
}
