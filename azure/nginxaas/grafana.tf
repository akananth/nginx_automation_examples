resource "azurerm_dashboard_grafana" "this" {
  name                = "${var.project_prefix}-grafana"
  location            = var.azure_region
  resource_group_name = var.resource_group_name

  identity {
    type = "SystemAssigned"
  }

  sku = "Standard"

  grafana_major_version = "11"

  tags = var.tags
}
