data "azurerm_container_registry" "acr" {
    name = var.acr_name
    resource_group_name = var.acr_resource_group_name
}

resource "azurerm_container_group" "dns-forwarder" {
    name = "dns-forwarder"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    ip_address_type = "Private"
    os_type = "Linux"
    subnet_ids = [azurerm_subnet.hub-subnet-aci.id] 

    container {
        name = "dns-forwarder"
        image = "${data.azurerm_container_registry.acr.login_server}/${var.dns_forwarder_image}"
        cpu = 1.0
        memory = 1.0
        ports {
            port = 53
            protocol = "UDP"
        }
    }

    image_registry_credential {
        server = data.azurerm_container_registry.acr.login_server
        username = data.azurerm_container_registry.acr.admin_username
        password = data.azurerm_container_registry.acr.admin_password
    }
}

resource "azurerm_virtual_network_dns_servers" "custom-dns" {
    virtual_network_id = azurerm_virtual_network.hub-vnet.id
    dns_servers = [azurerm_container_group.dns-forwarder.ip_address]
}