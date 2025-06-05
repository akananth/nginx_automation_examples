resource "azurerm_public_ip" "vm_pip" {
  count               = 2
  name                = "${var.project_prefix}-vm${count.index + 1}-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Create network interfaces for VMs
resource "azurerm_network_interface" "vm_nic" {
  count               = 2
  name                = "${var.project_prefix}-vm${count.index + 1}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_pip[count.index].id
  }
}

# Cloud-init template for NGINX Plus provisioning
data "template_file" "cloud_init" {
  template = file("${path.module}/cloud-init.tpl")

  vars = {
    nginx_cert = indent(6, var.nginx_plus_cert)
    nginx_key  = indent(6, var.nginx_plus_key)
    nginx_jwt  = indent(6, var.nginx_jwt)
  }
}

# Create Ubuntu VMs with NGINX Plus
resource "azurerm_linux_virtual_machine" "nginx_vm" {
  count               = 2
  name                = "${var.project_prefix}-vm${count.index + 1}"
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

  # Inject cloud-init config rendered and base64 encoded
  custom_data = base64encode(data.template_file.cloud_init.rendered)

  tags = var.tags
} 