# Data source to dynamically get the Role Definition ID for "Grafana Admin"
data "azurerm_role_definition" "grafana_admin" {
  name  = "Grafana Admin"
  scope = "/subscriptions/${var.subscription_id}"
}

resource "azurerm_dashboard_grafana" "this" {
  name                = "${var.project_prefix}-grafana"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  identity {
    type = "SystemAssigned"
  }

  sku                   = "Standard"
  grafana_major_version = "11"

  tags = var.tags
}

resource "azurerm_role_assignment" "grafana_admin" {
  scope              = azurerm_dashboard_grafana.this.id
  role_definition_id = data.azurerm_role_definition.grafana_admin.id
  principal_id       = azurerm_user_assigned_identity.main.principal_id

  depends_on = [
    azurerm_dashboard_grafana.this
  ]
}
