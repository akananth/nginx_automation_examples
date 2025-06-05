output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "subnet_id" {
  description = "ID of the created subnet"
  value       = azurerm_subnet.main.id
}

output "managed_identity_id" {
  description = "ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.main.id
}

output "nginx_endpoint" {
  description = "NGINXaaS public IP address"
  value       = azurerm_public_ip.main.ip_address
}

output "nginx_deployment_id" {
  description = "ID of the NGINXaaS deployment"
  value       = azurerm_nginx_deployment.main.id
}

output "vm_public_ips" {
  description = "Public IP addresses of the created VMs"
  value       = azurerm_public_ip.vm_pip[*].ip_address
}

output "vm_ssh_commands" {
  description = "SSH commands to connect to the created VMs"
  value       = [for ip in azurerm_public_ip.vm_pip : "ssh adminuser@${ip.ip_address}"]
}

output "vm_ids" {
  description = "IDs of the Azure Linux virtual machines"
  value       = [for vm in azurerm_linux_virtual_machine.nginx_vm : vm.id]
}

output "grafana_name" {
  value       = azurerm_dashboard_grafana.this.name
  description = "The name of the Azure Managed Grafana resource"
}

output "grafana_url" {
  value       = azurerm_dashboard_grafana.this.endpoint
  description = "The public endpoint of the Grafana dashboard"
}

