# outputs.tf
output "nginx_endpoint" {
  value = azurerm_public_ip.main.ip_address
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "subnet_id" {
  value = azurerm_subnet.main.id
}

output "managed_identity_id" {
  value = azurerm_user_assigned_identity.main.id
}

# NGINXaaS Outputs
output "nginx_endpoint" {
  description = "NGINXaaS public IP address"
  value       = azurerm_public_ip.main.ip_address
}

output "nginx_deployment_id" {
  description = "NGINXaaS deployment ID"
  value       = azurerm_nginx_deployment.main.id
}

# VM Outputs
output "vm_public_ips" {
  description = "Public IP addresses of the VMs"
  value       = [for vm in azurerm_linux_virtual_machine.nginx_vm : vm.public_ip_address]
}

output "vm_ssh_commands" {
  description = "SSH access commands for the VMs"
  value       = [for vm in azurerm_linux_virtual_machine.nginx_vm : "ssh adminuser@${vm.public_ip_address}"]
}

output "vm_ids" {
  description = "IDs of the created VMs"
  value       = [for vm in azurerm_linux_virtual_machine.nginx_vm : vm.id]
}