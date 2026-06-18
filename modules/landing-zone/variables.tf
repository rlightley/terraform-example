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

variable "vnet_address_space" {
  type        = list(string)
  description = "CIDR address space for the virtual network"
}

variable "subnets" {
  type = map(object({
    address_prefix    = string
    service_endpoints = optional(list(string), [])
  }))
  description = "Map of subnet names to their configuration"
}

variable "key_vault_sku" {
  type        = string
  description = "SKU tier for the Key Vault"
  default     = "standard"
  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku)
    error_message = "Key Vault SKU must be standard or premium."
  }
}

variable "key_vault_network_default_action" {
  type        = string
  description = "Default network action for Key Vault. Set to Deny for production with self-hosted runners or managed VNet runners."
  default     = "Allow"
  validation {
    condition     = contains(["Allow", "Deny"], var.key_vault_network_default_action)
    error_message = "Key Vault network default action must be Allow or Deny."
  }
}

variable "log_analytics_sku" {
  type        = string
  description = "SKU for the Log Analytics workspace"
  default     = "PerGB2018"
}

variable "log_retention_days" {
  type        = number
  description = "Number of days to retain logs in the workspace"
  default     = 30
  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Log retention must be between 30 and 730 days."
  }
}

variable "role_assignments" {
  type = map(object({
    principal_id         = string
    role_definition_name = string
  }))
  description = "Map of RBAC role assignments to create at the resource group scope. Key is a unique name for the assignment."
  default     = {}
}

variable "allowed_locations" {
  type        = list(string)
  description = "List of allowed Azure regions for the policy assignment. Leave empty to skip the policy assignment."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
