resource "azurerm_public_ip" "hub-p2s-vpn" {
    name = "dns-spike-hub-vpn"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    sku = "Standard"
    sku_tier = "Regional"
    allocation_method = "Static"
    domain_name_label = "dns-spike-vpngw"
}

resource "azurerm_virtual_network_gateway" "hub-p2s" {
    name = "dns-spike-hub-vpn"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    type = "Vpn"
    generation = "Generation1" # Gen2 needs > VpnGw1
    sku = "VpnGw1"
    vpn_type = "RouteBased"
    active_active = false
    enable_bgp = false

    ip_configuration {
        name = "dns-spike-hub-vpn-ip"
        public_ip_address_id = azurerm_public_ip.hub-p2s-vpn.id
        private_ip_address_allocation = "Dynamic"
        subnet_id = azurerm_subnet.hub-subnet-vpn.id
    }

    vpn_client_configuration {
        address_space = ["172.16.201.0/24"]
        aad_tenant = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}"
        aad_audience = "41b23e61-6c1e-4545-b367-cd054e0ed4b4" # https://learn.microsoft.com/en-gb/azure/vpn-gateway/openvpn-azure-ad-tenant-multi-app#add-a-client-application
        aad_issuer = "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/"
        vpn_client_protocols = ["OpenVPN"]
        vpn_auth_types = ["AAD"]
        
    }

    # ensures VPN clients route to the private endpoints subnet in the spoke
    custom_route {
        address_prefixes = [ azurerm_subnet.spoke1-subnet-pe.address_prefixes[0] ]
    }
}

