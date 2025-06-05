resource "azurerm_log_analytics_workspace" "nginx_logging" {
  name                = "${var.project_prefix}-azure-log"
  location            = var.azure_region
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "nginx_diagnostics" {
  name                       = "${var.project_prefix}-nginx-logs"
  target_resource_id         = azurerm_nginx_deployment.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.nginx_logging.id

  enabled_log {
    category = "NGINXLogs"
    enabled  = true
    retention_policy {
      enabled = false
      days    = 0
    }
  }

  enabled_log {
    category = "NGINXSecurityLogs"
    enabled  = true
    retention_policy {
      enabled = false
      days    = 0
    }
  }

  # optional, but safe for deployment order
  depends_on = [azurerm_nginx_deployment.main]
}
