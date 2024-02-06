provider "azurerm" {
    features {
        resource_group {
            prevent_deletion_if_contains_resources = true
        }
    }
}

# handy way to grab the current subscription and tenant
data "azurerm_client_config" "current" {}

terraform {
    backend "azurerm" {
        use_azuread_auth = true
        container_name = "tfstate"
        key = "private-resolver-spike.tfstate"
    }

    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = "~>3.85"
        }

        random = {
            source = "hashicorp/random"
            version = "~>3.1"
        }
    }
}