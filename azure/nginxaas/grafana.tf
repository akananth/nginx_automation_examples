# Get current subscription for role definition scope
data "azurerm_subscription" "current" {}

# Get Grafana Viewer role definition
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

# Lookup Azure AD users by email
data "azuread_user" "grafana_viewers" {
  for_each             = toset(var.grafana_viewer_emails)
  user_principal_name  = each.key
}

# Assign Grafana Viewer role to each user
resource "azurerm_role_assignment" "grafana_viewer" {
  for_each = data.azuread_user.grafana_viewers

  scope              = azurerm_dashboard_grafana.grafana.id
  role_definition_id = data.azurerm_role_definition.grafana_viewer.role_definition_resource_id
  principal_id       = each.value.object_id

  depends_on = [azurerm_dashboard_grafana.grafana]
}