# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_version = ">=1.5.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rave-rg" {
  name     = "rave-resources"
  location = "East US"
  tags = {
    environment = "dev"
  }
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "rave-net" {
  name                = "rave-network"
  resource_group_name = azurerm_resource_group.rave-rg.name
  location            = azurerm_resource_group.rave-rg.location
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet" "rave-sn" {
  name                 = "rave-subnet"
  resource_group_name  = azurerm_resource_group.rave-rg.name
  virtual_network_name = azurerm_virtual_network.rave-net.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "rave-sg" {
  name                = "rave-security-group"
  resource_group_name = azurerm_resource_group.rave-rg.name
  location            = azurerm_resource_group.rave-rg.location

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "rave-sgr" {
  name                        = "test123"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "98.246.178.213"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rave-rg.name
  network_security_group_name = azurerm_network_security_group.rave-sg.name
}

resource "azurerm_subnet_network_security_group_association" "rave-sga" {
  subnet_id                 = azurerm_subnet.rave-sn.id
  network_security_group_id = azurerm_network_security_group.rave-sg.id
}

resource "azurerm_public_ip" "rave-pip" {
  name                = "ravePublicIp1"
  resource_group_name = azurerm_resource_group.rave-rg.name
  location            = azurerm_resource_group.rave-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Dev"
  }
}

resource "azurerm_network_interface" "rave-nic" {
  name                = "rave-nic"
  resource_group_name = azurerm_resource_group.rave-rg.name
  location            = azurerm_resource_group.rave-rg.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.rave-sn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.rave-pip.id
  }

  tags = {
    environment = "Dev"
  }
}

resource "azurerm_linux_virtual_machine" "rave-vm" {
  name                  = "rave-vm"
  resource_group_name   = azurerm_resource_group.rave-rg.name
  location              = azurerm_resource_group.rave-rg.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.rave-nic.id]

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname = self.public_ip_address,
      user     = "adminuser"
    })
    interpreter = var.host_os == "linux" ? ["bash", "-c"] : ["Powershell", "-Command"]
  }

  tags = {
    environment = "dev"
  }
}

data "azurerm_public_ip" "rave-ips" {
  name                = azurerm_public_ip.rave-pip.name
  resource_group_name = azurerm_resource_group.rave-rg.name
}

output "rave_output_ip" {
  value = "${azurerm_linux_virtual_machine.rave-vm.name}: ${data.azurerm_public_ip.rave-ips.ip_address}"
}