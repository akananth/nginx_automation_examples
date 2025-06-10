terraform {
  required_version = "~> 1.3"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.30.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45.0"  # Added AzureAD provider
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

# Add AzureAD provider configuration
provider "azuread" {
  # Use Azure CLI authentication (same as azurerm)
  use_cli = true
}