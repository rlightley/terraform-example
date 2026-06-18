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
}

locals {
  resource_group_name   = "rg-${var.workload}-${var.environment}-${var.location_short}"
  app_service_plan_name = "asp-${var.workload}-${var.environment}-${var.location_short}"
  app_service_name      = "app-${var.workload}-${var.environment}-${var.location_short}"
  sql_server_name       = "sql-${var.workload}-${var.environment}-${var.location_short}"
  sql_database_name     = "sqldb-${var.workload}-${var.environment}-${var.location_short}"
}
