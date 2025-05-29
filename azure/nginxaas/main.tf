terraform {
  required_version = "~> 1.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.29.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id  # ADD THIS LINE
}

# Conditionally register provider only if not already registered
data "azurerm_resource_provider" "nginx" {
  name = "NGINX.NGINXPLUS"
}

resource "azurerm_resource_provider_registration" "nginx" {
  count = data.azurerm_resource_provider.nginx.registration_state == "Registered" ? 0 : 1
  name  = "NGINX.NGINXPLUS"
}

# Add a 2-minute wait only if registration was performed
resource "time_sleep" "wait_2_minutes" {
  count           = data.azurerm_resource_provider.nginx.registration_state == "Registered" ? 0 : 1
  depends_on      = [azurerm_resource_provider_registration.nginx]
  create_duration = "120s"
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.project_prefix}-rg"  # FIXED: name_prefix -> project_prefix
  location = var.azure_region            # FIXED: location -> azure_region
  tags     = var.tags
}

# Network Security Group
resource "azurerm_network_security_group" "main" {
  name                = "${var.project_prefix}-nsg"  # FIXED
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = var.security_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_prefix}-vnet"  # FIXED
  address_space       = var.address_space
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# Subnet with Delegation
resource "azurerm_subnet" "main" {
  name                 = "${var.project_prefix}-subnet"  # FIXED
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_prefix]

  delegation {
    name = "nginx-delegation"
    service_delegation {
      name    = "NGINX.NGINXPLUS/nginxDeployments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# NSG Association
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Public IP
resource "azurerm_public_ip" "main" {
  name                = "${var.project_prefix}-pip"  # FIXED
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Managed Identity
resource "azurerm_user_assigned_identity" "main" {
  name                = "${var.project_prefix}-identity"  # FIXED
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# Role Assignments
resource "azurerm_role_assignment" "contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

resource "azurerm_role_assignment" "network_contributor" {
  scope                = azurerm_subnet.main.id  # More granular scope
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

resource "null_resource" "wait_for_provider" {
  count = data.azurerm_resource_provider.nginx.registration_state == "Registered" ? 0 : 1
  
  provisioner "local-exec" {
    command = "sleep 120"
  }
}
# NGINX Deployment
resource "azurerm_nginx_deployment" "main" {
  depends_on = [
    null_resource.wait_for_provider,
    azurerm_role_assignment.contributor,
    azurerm_role_assignment.network_contributor,
    azurerm_subnet_network_security_group_association.main
  ]

  name                       = substr("${var.project_prefix}-deploy", 0, 40)  # FIXED
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.azure_region  # FIXED: location -> azure_region
  sku                        = var.sku
  capacity                   = var.capacity
  automatic_upgrade_channel  = "stable"
  diagnose_support_enabled   = true

  web_application_firewall {
    activation_state_enabled   = true
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  frontend_public {
    ip_address = [azurerm_public_ip.main.id]
  }

  network_interface {
    subnet_id = azurerm_subnet.main.id
  }

  tags = var.tags
}