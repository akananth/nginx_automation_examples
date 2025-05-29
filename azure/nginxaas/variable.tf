variable "project_prefix" {
  type        = string
  description = "Project prefix for resource naming (max 12 chars)"
  validation {
    condition     = length(var.project_prefix) <= 12
    error_message = "Project prefix must be 12 characters or less."
  }
}
# Add this to variables.tf
variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

# variables.tf
variable "azure_region" {
  type        = string
  description = "Azure deployment region"
  default     = "eastus2"
  validation {
    condition     = can(regex("^(east|west|central|north|south|uk|australia|southeastasia|eastasia)", lower(var.azure_region)))
    error_message = "Must be a valid Azure region name (e.g., eastus2, westeurope)."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name (derived from project prefix by default)"
  default     = "" # Will be set in locals
}

variable "sku" {
  type        = string
  description = "NGINXaaS SKU tier"
  default     = "standardv2_Monthly"
  validation {
    condition     = contains(["standardv2_Monthly", "standard_Monthly"], var.sku)
    error_message = "Valid SKUs: standardv2_Monthly, standard_Monthly."
  }
}

variable "capacity" {
  type        = number
  description = "NGINXaaS deployment capacity (10-100)"
  default     = 10
  validation {
    condition     = var.capacity >= 10 && var.capacity <= 100
    error_message = "Capacity must be between 10 and 100."
  }
}

variable "address_space" {
  type        = list(string)
  description = "Virtual network address space"
  default     = ["10.0.0.0/16"]
}

variable "subnet_prefix" {
  type        = string
  description = "Subnet CIDR block"
  default     = "10.0.1.0/24"
  validation {
    condition     = can(cidrsubnet(var.subnet_prefix, 0, 0)) # Valid CIDR check
    error_message = "Must be valid IPv4 CIDR notation."
  }
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

variable "security_rules" {
  type        = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  description = "Network security group rules"
  default = [{
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  },{
    name                       = "allow-https"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }]
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
  sensitive   = true
}

variable "nginx_plus_cert" {
  type        = string
  description = "NGINX Plus certificate (base64 encoded)"
  sensitive   = true
}

variable "nginx_plus_key" {
  type        = string
  description = "NGINX Plus private key (base64 encoded)"
  sensitive   = true
}

variable "storage_account_name" {
  type        = string
  description = "Storage account for Terraform state"
  validation {
    condition     = length(var.storage_account_name) >= 3 && length(var.storage_account_name) <= 24
    error_message = "Storage account name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "container_name" {
  type        = string
  description = "Storage container name"
  default     = "terraform-state"
}