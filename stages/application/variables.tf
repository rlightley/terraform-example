variable "workload" {
  type = string
}

variable "location" {
  type = string
}

variable "location_short" {
  type = string
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "state_backend_resource_group_name" {
  type        = string
  description = "Resource group of the Terraform state storage account (injected from config backend section)"
}

variable "state_backend_storage_account_name" {
  type        = string
  description = "Storage account name for the Terraform state (injected from config backend section)"
}

variable "state_backend_container_name" {
  type        = string
  description = "Container name for the Terraform state (injected from config backend section)"
}

variable "landing_zone_state_key" {
  type        = string
  description = "State key for the landing zone stage (injected from config backend.landing_zone_state_key)"
}

variable "vnet_integration_subnet_name" {
  type    = string
  default = "snet-app"
}

variable "app_service_plan_sku_name" {
  type    = string
  default = "B2"
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
  default = {}
}

variable "sql_database_sku_name" {
  type    = string
  default = "S1"
}

variable "sql_aad_admin_login" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
