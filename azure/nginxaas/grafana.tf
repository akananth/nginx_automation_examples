resource "azurerm_dashboard_grafana" "this" {
  name                = "${var.project_prefix}-grafana"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  identity {
    type = "SystemAssigned"
  }

  sku = "Standard"

  grafana_major_version = "11"

  tags = var.tags
}
