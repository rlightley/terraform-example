variable "workload" {
  type        = string
  description = "Workload name used to derive resource names"
}

variable "location" {
  type        = string
  description = "Azure region for all resources"
}

variable "location_short" {
  type        = string
  description = "Short region code used in resource names (e.g. uks, euw)"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "app_service_plan_sku_name" {
  type        = string
  description = "SKU name for the App Service Plan (e.g., B1, B2, S1, P1v3)"
  default     = "B2"
}

variable "app_stack" {
  type = object({
    dotnet_version      = optional(string)
    node_version        = optional(string)
    python_version      = optional(string)
    java_version        = optional(string)
    java_server         = optional(string)
    java_server_version = optional(string)
  })
  description = "Application runtime stack configuration. Only one runtime type should be specified."
  default     = {}
}

variable "sql_database_sku_name" {
  type        = string
  description = "SKU name for the SQL database (e.g., S0, S1, GP_S_Gen5_1)"
  default     = "S1"
}

variable "sql_aad_admin_login" {
  type        = string
  description = "Login name of the Azure AD administrator for the SQL server"
}

variable "vnet_integration_subnet_id" {
  type        = string
  description = "Subnet ID for App Service VNet integration"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics workspace ID for diagnostic settings"
}

variable "key_vault_id" {
  type        = string
  description = "Key Vault ID used to store generated secrets"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
