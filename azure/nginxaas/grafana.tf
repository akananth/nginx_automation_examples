# Lookup Azure AD users by email
data "azuread_user" "grafana_users" {
  for_each             = toset(var.grafana_viewer_emails)
  user_principal_name  = each.key
}

# Create Azure AD Group for Grafana Viewers
resource "azuread_group" "grafana_viewers" {
  display_name     = "${var.project_prefix}-grafana-viewers"
  security_enabled = true
}

# Add each user to the Grafana viewers group
resource "azuread_group_member" "grafana_viewer_members" {
  for_each = data.azuread_user.grafana_users

  group_object_id  = azuread_group.grafana_viewers.id
  member_object_id = each.value.object_id
}

# Get current subscription
data "azurerm_subscription" "current" {}

# Get role definition for "Grafana Viewer"
data "azurerm_role_definition" "grafana_viewer" {
  name  = "Grafana Viewer"
  scope = data.azurerm_subscription.current.id
}

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

# Assign Grafana Viewer role to the group
resource "azurerm_role_assignment" "grafana_viewer_assignment" {
  scope              = azurerm_dashboard_grafana.grafana.id
  role_definition_id = data.azurerm_role_definition.grafana_viewer.id
  principal_id       = azuread_group.grafana_viewers.id

  depends_on = [azurerm_dashboard_grafana.grafana]
}