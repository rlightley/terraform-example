resource "azurerm_role_assignment" "rg" {
  for_each = var.role_assignments

  scope                = azurerm_resource_group.main.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
}

data "azurerm_policy_definition" "allowed_locations" {
  count        = length(var.allowed_locations) > 0 ? 1 : 0
  display_name = "Allowed locations"
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  count                = length(var.allowed_locations) > 0 ? 1 : 0
  name                 = "allowed-locations"
  resource_group_id    = azurerm_resource_group.main.id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations[0].id
  display_name         = "Restrict deployments to allowed Azure regions"

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })
}
