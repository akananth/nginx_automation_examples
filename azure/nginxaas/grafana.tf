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

resource "azapi_resource" "grafana_dashboard" {
  type                     = "Microsoft.Dashboard/grafana/dashboards@2022-08-01"
  name                     = "n4-dashboard"
  parent_id                = azurerm_dashboard_grafana.this.id
  location                 = azurerm_resource_group.main.location

  schema_validation_enabled = false

  body = {
    properties = jsondecode(file("${path.module}/n4-dashboard.json"))
  }

  depends_on = [
    azurerm_dashboard_grafana.this
  ]
}
