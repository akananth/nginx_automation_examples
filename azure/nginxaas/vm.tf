Create network interfaces for VMs
resource "azurerm_network_interface" "vm_nic" {
  count               = 2
  name                = "${var.name_prefix}-vm${count.index + 1}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

# Create Ubuntu VMs with NGINX Plus
resource "azurerm_linux_virtual_machine" "nginx_vm" {
  count               = 2
  name                = "${var.name_prefix}-vm${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.vm_nic[count.index].id
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    nginx_cert = base64encode(var.nginx_plus_cert)
    nginx_key  = base64encode(var.nginx_plus_key)
  }))
}

# Cloud-init configuration file
resource "local_file" "cloud_init" {
  content = templatefile("${path.module}/cloud-init.tpl", {
    nginx_cert = base64encode(var.nginx_plus_cert)
    nginx_key  = base64encode(var.nginx_plus_key)
  })
  filename = "${path.module}/cloud-init.yaml"