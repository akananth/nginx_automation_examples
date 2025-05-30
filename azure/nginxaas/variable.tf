variable "project_prefix" {
  type        = string
  description = "Project prefix for resource naming (max 12 chars)"
  validation {
    condition     = length(var.project_prefix) <= 12
    error_message = "Project prefix must be 12 characters or less."
  }
}

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "azure_region" {
  type        = string
  description = "Azure deployment region"
  default     = "eastus2"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
  default     = ""
}

variable "sku" {
  type        = string
  description = "NGINXaaS SKU tier"
  default     = "standardv2_Monthly"
}

variable "capacity" {
  type        = number
  description = "NGINXaaS deployment capacity"
  default     = 10
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
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
  sensitive   = true
}

variable "nginx_jwt" {
  description = "NGINX Plus JWT license"
  type        = string
  sensitive   = true
}

variable "nginx_plus_cert" {
  type        = string
  description = "Base64 encoded NGINX Plus certificate"
  sensitive   = true
}

variable "nginx_plus_key" {
  type        = string
  description = "Base64 encoded NGINX Plus private key"
  sensitive   = true
}

variable "storage_account_name" {
  type        = string
  description = "Storage account for Terraform state"
}

variable "container_name" {
  type        = string
  description = "Storage container name"
  default     = "terraform-state"
}

variable "allowed_ip" {
  type        = string
  description = "Your current public IP for security rules"
  default     = ""
}