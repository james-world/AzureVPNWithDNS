resource "azurerm_storage_account" "dns-spike-storage" {
    name = "dnsspikestorage"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    account_tier = "Standard"
    account_replication_type = "LRS"
    min_tls_version = "TLS1_2"

    network_rules {
        default_action = "Deny"
        ip_rules = []
    }
}

resource "azurerm_private_endpoint" "dns-spike-storage-pe" {
    name = "dns-spike-storage-pe"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    subnet_id = azurerm_subnet.spoke1-subnet-pe.id

    private_service_connection {
        name = "dns-spike-storage-pe-connection"
        is_manual_connection = false
        private_connection_resource_id = azurerm_storage_account.dns-spike-storage.id
        subresource_names = ["blob"]
    }

    private_dns_zone_group {
        name = "dns-spike-storage-pe-dns-zone-group"
        private_dns_zone_ids = [azurerm_private_dns_zone.dns-spike-dns-zone.id]
    }
}