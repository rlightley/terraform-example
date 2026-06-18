terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

locals {
  resource_group_name          = "rg-${var.workload}-${var.environment}-${var.location_short}"
  vnet_name                    = "vnet-${var.workload}-${var.environment}-${var.location_short}"
  key_vault_name               = "kv-${var.workload}-${var.environment}-${var.location_short}"
  log_analytics_workspace_name = "log-${var.workload}-${var.environment}-${var.location_short}"
}

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}
