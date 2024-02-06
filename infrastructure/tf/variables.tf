variable "create_vm" {
    type = bool
    default = false
}

variable "acr_name" {
    type = string
    description = "name of your Azure Container Registry for storing the DNS Forwarder image"
}

variable "acr_resource_group_name" {
    type = string
    description = "resource group name of your Azure Container Registry"
}

variable "dns_forwarder_image" {
    type = string
    default = "az-dns-forwarder:1.0"
}