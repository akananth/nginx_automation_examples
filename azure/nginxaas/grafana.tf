resource "azurerm_dashboard_grafana" "this" {
  name                   = "${var.project_prefix}-grafana"
  location               = azurerm_resource_group.main.location
  resource_group_name    = azurerm_resource_group.main.name

  identity {
    type = "SystemAssigned"
  }

  sku                   = "Standard"
  grafana_major_version = "11"

  tags = var.tags
}

resource "azurerm_role_assignment" "grafana_viewer" {
  scope                = azurerm_dashboard_grafana.this.id     # use "this" here
  role_definition_name = "Grafana Viewer"
  principal_id         = azurerm_user_assigned_identity.main.principal_id

  depends_on = [
    azurerm_dashboard_grafana.this
  ]
}
