resource "azurerm_service_plan" "main" {
  name                = local.app_service_plan_name
  resource_group_name = local.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku_name
  tags                = var.tags
}

resource "azurerm_linux_web_app" "main" {
  name                      = local.app_service_name
  resource_group_name       = local.resource_group_name
  location                  = var.location
  service_plan_id           = azurerm_service_plan.main.id
  https_only                = true
  virtual_network_subnet_id = var.vnet_integration_subnet_id

  site_config {
    minimum_tls_version = "1.2"
    http2_enabled       = true

    dynamic "application_stack" {
      for_each = length([for k, v in var.app_stack : v if v != null]) > 0 ? [var.app_stack] : []
      content {
        dotnet_version      = application_stack.value.dotnet_version
        node_version        = application_stack.value.node_version
        python_version      = application_stack.value.python_version
        java_version        = application_stack.value.java_version
        java_server         = application_stack.value.java_server
        java_server_version = application_stack.value.java_server_version
      }
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING"      = azurerm_application_insights.main.connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
    "WEBSITE_RUN_FROM_PACKAGE"                   = "1"
  }

  tags = var.tags
}

resource "azurerm_application_insights" "main" {
  name                = "appi-${local.app_service_name}"
  resource_group_name = local.resource_group_name
  location            = var.location
  workspace_id        = var.log_analytics_workspace_id
  application_type    = "web"
  tags                = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "app_service" {
  name                       = "diag-${local.app_service_name}"
  target_resource_id         = azurerm_linux_web_app.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceAppLogs"
  }

  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  metric {
    category = "AllMetrics"
  }
}
