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

variable "vnet_address_space" {
  type = list(string)
}

variable "subnets" {
  type = map(object({
    address_prefix    = string
    service_endpoints = optional(list(string), [])
  }))
}

variable "key_vault_sku" {
  type    = string
  default = "standard"
}

variable "key_vault_network_default_action" {
  type    = string
  default = "Allow"
}

variable "log_analytics_sku" {
  type    = string
  default = "PerGB2018"
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "role_assignments" {
  type = map(object({
    principal_id         = string
    role_definition_name = string
  }))
  default = {}
}

variable "allowed_locations" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
