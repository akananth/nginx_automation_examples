# Get current subscription (needed for scoping role assignments)
data "azurerm_subscription" "current" {}

# Get role definition for Grafana Admin
data "azurerm_role_definition" "grafana_admin" {
  name  = "Grafana Admin"
  scope = data.azurerm_subscription.current.id
}

# Get role definition for Monitoring Reader
data "azurerm_role_definition" "monitoring_reader" {
  name  = "Monitoring Reader"
  scope = data.azurerm_subscription.current.id
}

# Create Grafana instance
resource "azurerm_dashboard_grafana" "grafana" {
  name                = "${var.project_prefix}-grafana"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  identity {
    type = "SystemAssigned"
  }

  sku                   = "Standard"
  grafana_major_version = "11"
}

# Get the Grafana Azure AD Application automatically (must be after grafana creation)
data "azuread_application" "grafana_app" {
  display_name = azurerm_dashboard_grafana.grafana.name
  depends_on   = [azurerm_dashboard_grafana.grafana]
}

# Get the Service Principal associated with the Grafana application
data "azuread_service_principal" "grafana_sp" {
  application_id = data.azuread_application.grafana_app.application_id
  depends_on     = [data.azuread_application.grafana_app]
}

# Assign Grafana Admin role to each provided user
resource "azurerm_role_assignment" "grafana_admin_users" {
  for_each = toset(var.grafana_admin_object_ids)

  scope              = azurerm_dashboard_grafana.grafana.id
  role_definition_id = data.azurerm_role_definition.grafana_admin.id
  principal_id       = each.value

  depends_on = [azurerm_dashboard_grafana.grafana]
}

# Assign Grafana Admin role to Grafana's system-assigned identity
resource "azurerm_role_assignment" "grafana_admin_app" {
  scope              = azurerm_dashboard_grafana.grafana.id
  role_definition_id = data.azurerm_role_definition.grafana_admin.id
  principal_id       = azurerm_dashboard_grafana.grafana.identity[0].principal_id

  depends_on = [azurerm_dashboard_grafana.grafana]
}

# Comprehensive monitoring permissions
resource "azurerm_role_assignment" "grafana_monitoring_permissions" {
  for_each = {
    # Cover all necessary scopes
    "subscription" = data.azurerm_subscription.current.id,
    "resource_group" = azurerm_resource_group.main.id,
    "nginx" = azurerm_nginx_deployment.main.id
  }

  scope              = each.value
  role_definition_id = data.azurerm_role_definition.monitoring_reader.id
  # Assign to both identities
  principal_id       = azurerm_dashboard_grafana.grafana.identity[0].principal_id

  depends_on = [
    azurerm_dashboard_grafana.grafana,
    azurerm_nginx_deployment.main
  ]
}

# Additional assignment for the Service Principal if needed
resource "azurerm_role_assignment" "grafana_sp_monitoring_permissions" {
  for_each = {
    "subscription" = data.azurerm_subscription.current.id,
    "resource_group" = azurerm_resource_group.main.id
  }

  scope              = each.value
  role_definition_id = data.azurerm_role_definition.monitoring_reader.id
  principal_id       = data.azuread_service_principal.grafana_sp.object_id

  depends_on = [
    data.azuread_service_principal.grafana_sp,
    azurerm_dashboard_grafana.grafana
  ]
}