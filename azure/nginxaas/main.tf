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
  }
  
  # Provider Registration (Must be first)
  resource "azurerm_resource_provider_registration" "nginx" {
    name = "NGINX.NGINXPLUS"
  }
  
  resource "time_sleep" "wait_2_minutes" {
    depends_on      = [azurerm_resource_provider_registration.nginx]
    create_duration = "120s"
  }
  
  # Resource Group
  resource "azurerm_resource_group" "main" {
    name     = "${var.name_prefix}-rg"
    location = var.location
    tags     = var.tags
  }
  
  # Network Security Group
  resource "azurerm_network_security_group" "main" {
    name                = "${var.name_prefix}-nsg"
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
    name                = "${var.name_prefix}-vnet"
    address_space       = var.address_space
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name
    tags                = var.tags
  }
  
  # Subnet with Delegation
  resource "azurerm_subnet" "main" {
    name                 = "${var.name_prefix}-subnet"
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
    name                = "${var.name_prefix}-pip"
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name
    allocation_method   = "Static"
    sku                 = "Standard"
    tags                = var.tags
  }
  
  # Managed Identity
  resource "azurerm_user_assigned_identity" "main" {
    name                = "${var.name_prefix}-identity"
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
  
    name                       = substr("${var.name_prefix}-deploy", 0, 40)
    resource_group_name        = azurerm_resource_group.main.name
    location                   = var.location
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