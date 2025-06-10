# grafana.tf
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_role_definition" "grafana_admin" {
  name  = "Grafana Admin"
  scope = "/subscriptions/${var.subscription_id}"
}

resource "azurerm_dashboard_grafana" "grafana" {
  name                = "${var.project_prefix}-grafana"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  identity {
    type = "SystemAssigned"
  }

  sku                   = "Standard"
  grafana_major_version = "11"
}

resource "azurerm_role_assignment" "grafana_admin_assignment" {
  scope              = azurerm_dashboard_grafana.grafana.id
  role_definition_id = data.azurerm_role_definition.grafana_admin.id
  principal_id       = azurerm_dashboard_grafana.grafana.identity[0].principal_id

  depends_on = [azurerm_dashboard_grafana.grafana]
}
