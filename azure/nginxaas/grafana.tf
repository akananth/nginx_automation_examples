
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

# Get current subscription (needed for role scope)
data "azurerm_subscription" "current" {}

# Lookup role definition ID for "Grafana Viewer"
data "azurerm_role_definition" "grafana_viewer" {
  name  = "Grafana Viewer"
  scope = data.azurerm_subscription.current.id
}

# Assign Grafana Viewer role to each provided Object ID
resource "azurerm_role_assignment" "grafana_viewer" {
  for_each = toset(var.grafana_viewer_object_ids)

  scope              = azurerm_dashboard_grafana.grafana.id
  role_definition_id = data.azurerm_role_definition.grafana_viewer.id
  principal_id       = each.value

  depends_on = [azurerm_dashboard_grafana.grafana]
}
