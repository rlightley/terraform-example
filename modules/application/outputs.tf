output "app_service_id" {
  description = "Resource ID of the App Service"
  value       = azurerm_linux_web_app.main.id
}

output "app_service_default_hostname" {
  description = "Default hostname of the App Service"
  value       = azurerm_linux_web_app.main.default_hostname
}

output "app_service_principal_id" {
  description = "System-assigned managed identity principal ID of the App Service"
  value       = azurerm_linux_web_app.main.identity[0].principal_id
}

output "sql_server_id" {
  description = "Resource ID of the SQL Server"
  value       = azurerm_mssql_server.main.id
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL Server"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_database_id" {
  description = "Resource ID of the SQL database"
  value       = azurerm_mssql_database.main.id
}

output "application_insights_id" {
  description = "Resource ID of the Application Insights instance"
  value       = azurerm_application_insights.main.id
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  sensitive   = true
  value       = azurerm_application_insights.main.connection_string
}
