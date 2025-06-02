terraform {
  required_version = "~> 1.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.29.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.1"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}


locals {
  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : "${var.project_prefix}-rg"
  allowed_ip         = var.allowed_ip != "" ? var.allowed_ip : chomp(data.http.myip.response_body)
  
  security_rules = [
    {
      name                       = "allow-http"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "${local.allowed_ip}/32"
      destination_address_prefix = "*"
    },
    {
      name                       = "allow-https"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "${local.allowed_ip}/32"
      destination_address_prefix = "*"
    },
    {
      name                       = "allow-ssh"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "${local.allowed_ip}/32"
      destination_address_prefix = "*"
    }
  ]
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.azure_region
  tags     = var.tags
}

# Provider Registration (Must be first)
resource "azurerm_resource_provider_registration" "nginx" {
  name = "NGINX.NGINXPLUS"
}

resource "time_sleep" "wait_2_minutes" {
  depends_on      = [azurerm_resource_provider_registration.nginx]
  create_duration = "120s"
}

# Network Security Group
resource "azurerm_network_security_group" "main" {
  name                = "${var.project_prefix}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = local.security_rules
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
  name                = "${var.project_prefix}-vnet"
  address_space       = var.address_space
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# Subnet with Delegation
resource "azurerm_subnet" "main" {
  name                 = "${var.project_prefix}-subnet"
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

# Public IP for NGINX
resource "azurerm_public_ip" "main" {
  name                = "${var.project_prefix}-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Managed Identity
resource "azurerm_user_assigned_identity" "main" {
  name                = "${var.project_prefix}-identity"
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
  scope                = azurerm_virtual_network.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

# NGINX Deployment
resource "azurerm_nginx_deployment" "main" {
  depends_on = [
    time_sleep.wait_2_minutes,
    azurerm_role_assignment.contributor,
    azurerm_role_assignment.network_contributor,
    azurerm_subnet_network_security_group_association.main
  ]

  name                       = substr("${var.project_prefix}-deploy", 0, 40)
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.azure_region
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