# a cheeky public ip so we can remote in to the VM
resource "azurerm_public_ip" "vm-public-ip" {
    count = var.create_vm ? 1 : 0

    name = "dns-spike-vm-public-ip"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    allocation_method = "Static"
    sku = "Standard"
}

# create a network security group to allow inbound rdp
resource "azurerm_network_security_group" "vm-nsg" {
    count = var.create_vm ? 1 : 0

    name = "dns-spike-vm-nsg"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location

    security_rule {
        name = "allow-rdp"
        priority = 1001
        direction = "Inbound"
        access = "Allow"
        protocol = "*"
        source_port_range = "*"
        destination_port_range = "3389"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }
}

# create a nic for the vm
resource "azurerm_network_interface" "vm-nic" {
    count = var.create_vm ? 1 : 0

    name = "dns-spike-vm-nic"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location

    ip_configuration {
        name = "dns-spike-vm-ip-config"
        subnet_id = azurerm_subnet.hub-subnet-vms.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id = azurerm_public_ip.vm-public-ip[0].id
    }
}

# connect the security group to the nic
resource "azurerm_network_interface_security_group_association" "vm-nic-nsg" {
    count = var.create_vm ? 1 : 0

    network_interface_id = azurerm_network_interface.vm-nic[0].id
    network_security_group_id = azurerm_network_security_group.vm-nsg[0].id
}

# create the vm
resource "azurerm_virtual_machine" "vm" {
    count = var.create_vm ? 1 : 0

    name = "dns-spike-vm"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    network_interface_ids = [azurerm_network_interface.vm-nic[0].id]
    vm_size = "Standard_B2s"
    delete_os_disk_on_termination = true
    delete_data_disks_on_termination = true

    storage_image_reference {
        publisher = "MicrosoftWindowsDesktop"
        offer = "Windows-11"
        sku = "win11-21h2-pro"
        version = "latest"
    }

    storage_os_disk {
        name = "dns-spike-vm-os-disk"
        caching = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    os_profile {
        computer_name = "dns-spike-vm"
        admin_username = "dns-spike-admin"
        admin_password = "fruit-of-THE-loom"
    }

    os_profile_windows_config {
        provision_vm_agent = true
    }
}

