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
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

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

  resource_group_name        = data.terraform_remote_state.landing_zone.outputs.resource_group_name
  location                   = var.location
  environment                = var.environment
  app_service_plan_name      = var.app_service_plan_name
  app_service_plan_sku_name  = var.app_service_plan_sku_name
  app_service_name           = var.app_service_name
  app_stack                  = var.app_stack
  sql_server_name            = var.sql_server_name
  sql_database_name          = var.sql_database_name
  sql_database_sku_name      = var.sql_database_sku_name
  sql_aad_admin_login        = var.sql_aad_admin_login
  sql_aad_admin_object_id    = var.sql_aad_admin_object_id
  vnet_integration_subnet_id = data.terraform_remote_state.landing_zone.outputs.subnet_ids[var.vnet_integration_subnet_name]
  log_analytics_workspace_id = data.terraform_remote_state.landing_zone.outputs.log_analytics_workspace_id
  key_vault_id               = data.terraform_remote_state.landing_zone.outputs.key_vault_id
  tags                       = var.tags
}
