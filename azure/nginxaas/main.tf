terraform {
  required_version = "~> 1.3"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.30.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.1"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">=1.5.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : "${var.project_prefix}-rg"

  security_rules = [
    {
      name                       = "allow-http"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "${var.admin_ip}/32"
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
      source_address_prefix      = "${var.admin_ip}/32"
      destination_address_prefix = "*"
    }
  ]
}

resource "null_resource" "validate_admin_ip" {
  provisioner "local-exec" {
    command = <<EOT
      if [ -z "${var.admin_ip}" ]; then
        echo "ERROR: admin_ip must be set for SSH access"
        exit 1
      fi
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "azurerm_resource_provider_registration" "nginx" {
  name = "NGINX.NGINXPLUS"
}

resource "time_sleep" "wait_1_minutes" {
  depends_on      = [azurerm_resource_provider_registration.nginx]
  create_duration = "60s"
}

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.azure_region
  tags     = var.tags
}

resource "azurerm_network_security_group" "main" {
  name                = "${var.project_prefix}-nsg"
  location            = var.azure_region
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

resource "azurerm_network_security_rule" "ssh_rule" {
  name                        = "allow-ssh"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "${var.admin_ip}/32"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.project_prefix}-vnet"
  address_space       = var.address_space
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

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

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_public_ip" "main" {
  name                = "${var.project_prefix}-pip"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "main" {
  name                = "${var.project_prefix}-identity"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

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

resource "azurerm_nginx_deployment" "main" {
  depends_on = [
    time_sleep.wait_1_minutes,
    azurerm_role_assignment.contributor,
    azurerm_role_assignment.network_contributor,
    azurerm_subnet_network_security_group_association.main
  ]

  name                        = substr("${var.project_prefix}-deploy", 0, 40)
  resource_group_name         = azurerm_resource_group.main.name
  location                    = var.azure_region
  sku                         = var.sku
  capacity                    = var.capacity
  automatic_upgrade_channel   = "stable"
  diagnose_support_enabled    = true

  identity {
   type         = "SystemAssigned, UserAssigned" 
   identity_ids = [azurerm_user_assigned_identity.main.id]
  }


  frontend_public {
    ip_address = [azurerm_public_ip.main.id]
  }

  network_interface {
    subnet_id = azurerm_subnet.main.id
  }

  web_application_firewall {
    activation_state_enabled = true
  }

  tags = var.tags
}
