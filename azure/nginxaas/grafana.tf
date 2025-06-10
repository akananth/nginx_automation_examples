provider "azuread" {}

data "azurerm_subscription" "current" {}

# Use subscription scope for role definition lookup
data "azurerm_role_definition" "grafana_viewer" {
  name  = "Grafana Viewer"
  scope = data.azurerm_subscription.current.id
}

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

# Look up user by email address instead of using object ID directly
data "azuread_user" "grafana_user" {
  user_principal_name = var.grafana_user_email 
}

resource "azurerm_role_assignment" "grafana_viewer_assignment" {
  scope              = azurerm_dashboard_grafana.grafana.id
  role_definition_id = data.azurerm_role_definition.grafana_viewer.role_definition_resource_id
  principal_id       = data.azuread_user.grafana_user.object_id

  depends_on = [azurerm_dashboard_grafana.grafana]
}