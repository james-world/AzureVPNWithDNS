# this resource group will contain all resources
# in this spike
resource "azurerm_resource_group" "rg" {
    name = "dns-spike"
    location = "uksouth"
}

# create the virtual networks and subnets for the
# hub and spoke

resource "azurerm_virtual_network" "hub-vnet" {
    name = "dns-spike-hub-vnet"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    address_space = ["10.30.0.0/16"]
}

resource "azurerm_subnet" "hub-subnet-vms" {
    name = "dns-spike-hub-vms"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.hub-vnet.name
    address_prefixes = ["10.30.0.0/24"]
}

resource "azurerm_subnet" "hub-subnet-aci" {
    name = "dns-spike-hub-aci"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.hub-vnet.name
    address_prefixes = ["10.30.1.0/24"]

    # this subnet is delegated to the container instance service
    delegation {
        name = "dns-spike-hub-aci-delegation"
        service_delegation {
            name = "Microsoft.ContainerInstance/containerGroups"
            actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
        }
    }
}

resource "azurerm_subnet" "hub-subnet-vpn" {
    # this *must* be the name of the subnet, as required by MS
    name = "GatewaySubnet"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.hub-vnet.name
    address_prefixes = ["10.30.2.0/24"]
}

resource "azurerm_virtual_network" "spoke1-vnet" {
    name = "dns-spike-spoke1-vnet"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    address_space = ["10.35.0.0/16"]
}

resource "azurerm_subnet" "spoke1-subnet-pe" {
    name = "dns-spike-spoke1-pe"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.spoke1-vnet.name
    address_prefixes = ["10.35.0.0/24"]
}

# create the peering between the hub and spoke
# this requires peering from both sides

resource "azurerm_virtual_network_peering" "hub-to-spoke1" {
    name = "dns-spike-hub-to-spoke1"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.hub-vnet.name
    remote_virtual_network_id = azurerm_virtual_network.spoke1-vnet.id
}

resource "azurerm_virtual_network_peering" "spoke1-to-hub" {
    name = "dns-spike-spoke1-to-hub"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.spoke1-vnet.name
    remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id
    allow_forwarded_traffic = true
    allow_virtual_network_access = true
}

# create a private dns zone for blob storage
# we need this for the private endpoint
resource "azurerm_private_dns_zone" "dns-spike-dns-zone" {
    name = "privatelink.blob.core.windows.net"
    resource_group_name = azurerm_resource_group.rg.name
}

# link the private dns zone to the spoke and hub
# so resources in both vnets can resolve the private endpoint

resource "azurerm_private_dns_zone_virtual_network_link" "dns-spike-spoke-dns-link" {
    name = "dns-spike-spoke1-dns-link"
    resource_group_name = azurerm_resource_group.rg.name
    private_dns_zone_name = azurerm_private_dns_zone.dns-spike-dns-zone.name
    virtual_network_id = azurerm_virtual_network.spoke1-vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns-spike-hub-dns-link" {
    name = "dns-spike-hub-dns-link"
    resource_group_name = azurerm_resource_group.rg.name
    private_dns_zone_name = azurerm_private_dns_zone.dns-spike-dns-zone.name
    virtual_network_id = azurerm_virtual_network.hub-vnet.id
}