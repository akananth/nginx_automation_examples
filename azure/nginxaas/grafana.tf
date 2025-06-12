
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

# ✅ Assign Grafana Viewer role to the Grafana instance's system-assigned identity
resource "azurerm_role_assignment" "grafana_viewer_app" {
  scope              = azurerm_dashboard_grafana.grafana.id
  role_definition_id = data.azurerm_role_definition.grafana_viewer.id
  principal_id       = azurerm_dashboard_grafana.grafana.identity[0].principal_id

  depends_on = [azurerm_dashboard_grafana.grafana]
}

# Upload dashboard.json to Grafana
resource "null_resource" "import_grafana_dashboard" {
  triggers = {
    dashboard_sha = filesha1("${path.module}/dashboard.json") # Re-run if dashboard changes
    grafana_id    = azurerm_dashboard_grafana.grafana.id
  }

    provisioner "local-exec" {
    command = <<-EOT
      az grafana dashboard import \
        --name "${azurerm_dashboard_grafana.grafana.name}" \
        --resource-group "${azurerm_dashboard_grafana.grafana.resource_group_name}" \
        --definition @"${path.module}/dashboard.json"
    EOT
  }

  depends_on = [
    azurerm_dashboard_grafana.grafana,
    azurerm_role_assignment.grafana_viewer
    azurerm_role_assignment.grafana_viewer_app
  ]
}