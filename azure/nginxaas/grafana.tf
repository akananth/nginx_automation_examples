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

resource "azurerm_role_assignment" "grafana_viewer" {
  scope                = azurerm_dashboard_grafana.this.id
  role_definition_name = "Grafana Viewer"
  principal_id         = var.grafana_user_object_id

  depends_on = [azurerm_dashboard_grafana.this]
}

resource "azurerm_template_deployment" "grafana_dashboard_import" {
  name                = "grafana-n4-dashboard-import"
  resource_group_name = azurerm_resource_group.main.name
  deployment_mode     = "Incremental"

  parameters = {
    grafanaName     = azurerm_dashboard_grafana.this.name
    dashboardName   = "n4-dashboard"
    dashboardJson   = base64encode(file("${path.module}/nginxaas/n4-dashboard.json"))
  }

  template_body = <<DEPLOY
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "grafanaName": {
      "type": "string"
    },
    "dashboardName": {
      "type": "string"
    },
    "dashboardJson": {
      "type": "string"
    }
  },
  "resources": [
    {
      "type": "Microsoft.Dashboard/grafana/dashboards",
      "apiVersion": "2022-08-01",
      "name": "[concat(parameters('grafanaName'), '/', parameters('dashboardName'))]",
      "properties": {
        "dashboard": "[base64ToString(parameters('dashboardJson'))]"
      }
    }
  ]
}
DEPLOY

  depends_on = [azurerm_dashboard_grafana.this]
}
