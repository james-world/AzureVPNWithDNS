# Azure P2S VPN to Securely Access Azure Resources

This spike demonstrates how to use Azure P2S VPN with Azure AD Authentication using an Azure Container Instance hosted custom DNS server image to securely access Azure resources without using host files.

I also considered using an Azure DNS Private Resolver - but at ~ £140 per month per inbound connection, this is basically daylight robbery compared to the ACI approach.

## Prerequisites

- An Azure Subscription, with an Azure Container Registry (ACR) in it. You will need to be able to push images to the ACR.
- Docker Desktop is also required to build the DNS forwarder image. Building and publishing the image is not automated in the terraform. Manual instructions are provided below.

## Plan

1. [x] Create an Azure VNet called `dns-spike-hub`. This will be the hub virtual network and will contain the VPN Gateway.
2. [x] Create a SubNet in the hub vnet called `hub-subnet-vms`. This will be a subnet for a VM to test connectivity to a storage account in a spoke.
3. [x] Create an Azure VNet called `dns-spike-spoke1`, peered to the hub virtual network. This will be the spoke virtual network and will contain the storage account.
4. [x] Create a SubNet in the spoke called `spoke1-subnet-pe`. This will be a subnet for a private endpoint to the storage account.
5. [x] Peer Hub and Spoke1. Create a private DNS zone and link it to the hub and spoke virtual networks.
6. [x] Deploy a Storage Account.
7. [x] Create a Private Endpoint to the Storage Account in the spoke1 subnet and add it to the private DNS zone.
8. [x] Deploy a Windows 11 VM called `dns-spike-vm` into HubVMs.
9. [x] Check the Storage Account is accessible from the VM in HubVMs.
10. [x] Build a containerized DNS forwarder and **manually** publish to an ACR in your subscription.
11. [x] Add the DNS forwarder to a subnet in the hub vnet and configure the hub vnet to use it. Test connectivity to the storage account from the VM in HubVMs.
12. [x] Deploy a VPN Gateway into Hub VNet and set up P2S VPN
13. [x] Setup Azure Client and VPN in to the VPN Gateway and check the Storage Account is accessible from the remote client.

## Terraform

The Terraform backend provider is used to store the state of the infrastructure in Azure Storage. This is required to allow multiple developers to work on the same infrastructure without overwriting each other's changes. Initialize the backend provider as follows (substitute the storage account name for your own):

```bash
terraform -chdir=infrastructure/tf init -backend-config="storage_account_name={your-storage-account}"
```

To deploy the infrastructure, run the following commands:

```bash
terraform -chdir=infrastructure/tf plan -out=tf.plan
terraform -chdir=infrastructure/tf apply tf.plan
```

The ACR name and resource group are passed in as variables. If you want to use a different ACR, include `-var "acr_name=<your-acr-name>" -var "acr_resource_group_name=<your-acr-rg>"` in the above commands, or set the environment variables `TF_VAR_acr_name` and `TF_VAR_acr_resource_group_name`.

If you want to create a VM in the hub to test connectivity to the storage account, run the following commands instead:

```bash
terraform -chdir=infrastructure/tf plan -out=tf.plan -var "create_vm=true"
terraform -chdir=infrastructure/tf apply tf.plan
```

Run the following to destroy the infrastructure. Note that it might take a few goes as Azure sometimes fails to clean up VM components in a timely manner and times out deleting dependent resources.

```bash
terraform -chdir=infrastructure/tf destroy
```

## Resources

All resources are deployed into the 'dns-spike' resource group.

### Deployment Diagram

![Deployment Diagram](Deployment%20Diagram.drawio.svg)

## DNS Resolution for VPN Clients

There are a few options here:

- Use an Azure DNS Private Resolver. Criminally expensive (about 149 CHF per month per inbound connection (we'd need 1 per platform)).
- Use a custom DNS server that fowards to Azure DNS Private Zones. We will explore this option initally.

### Custom DNS Server

Build it from the root with:

```bash
docker build --platform linux/amd64 -t az-dns-forwarder:1.0 -f src/Dockerfile src
```

It needs to available to deploy from an ACR accessible to terraform. Tag it with the ACR name and push it to the ACR.

```bash
docker tag az-dns-forwarder:1.0 <acr-name>.azurecr.io/az-dns-forwarder:1.0
```

Login in and push to the ACR with:

```bash
az acr login --name <acr-name>
docker push <acr-name>.azurecr.io/az-dns-forwarder:1.0
```

### Container Instance deployment timeouts

I experienced a timeout during a deploying where the ACI exceeded it's 30 minute window. The container actually successfully deployed but the terraform failed. In order to re-apply the terraform I had to import the ACI into the state with the terraform import command. I obtained resource id required for the import command (the final argument) by looking it up with the az cli: `az container list --query "[].{Name:name, ID:id}" --output table -g dns-spike`.

```bash
terraform -chdir=infrastructure/tf import azurerm_container_group.dns-forwarder /subscriptions/<my-sub>/resourceGroups/dns-spike/providers/Microsoft.ContainerInstance/containerGroups/dns-forwarder
```

Re-running the terraform was necssary to apply the dependent settings - and still required destroying/recreating the ACI (because tf couldn't see the ACI password). I could probably have fixed this, but it was quicker to destroy and recreate and the container created extremely quickly this time.

### VPN Gateway Configuration Notes

- It's really important to set the custom routes to advertise the Private Endpoints. This is the set in the [custom_route](infrastructure/tf/vpn_gateway.tf) property
- The settings file can be downloaded from the Azure Portal blade for the VPN Gateway in the Point To Site section. It's a zip file containing folders for generic VPN cliens and the Azure VPN client. These xml files can be imported into the VPN Clients to configure their connections. The Azure VPN client is available for Windows and Mac, and I tested it on Mac OS with M1 chips.
- This file does NOT need to be redownloaded if custom routes change. The custom routes are not included in the file, and are configured on the VPN Gateway in Azure. However, clients will need to reconnect to pick up new settings. If the DNS Server IP changes (which it shouldn't), the file will need to be redownloaded.
- In order for AD Auth to work, the Azure VPN Enterprise Application must be granted access in your Azure AD Tenant. See [here](https://learn.microsoft.com/en-gb/azure/vpn-gateway/openvpn-azure-ad-tenant-multi-app#authorize-the-azure-vpn-application) for details.
- Use `netstat -rn` on a Mac to check the routes are being added correctly. The routes should be added when the VPN is connected, and removed when it is disconnected. Use `dig` to check the DNS server is being used correctly - e.g. `dig dnsspikestorage.blob.core.windows.net` should return the storage account private endpoint IP address. Use `route print -4` and `nslookup` on Windows to make the same checks.

## Cost Notes

The VPN Gateway is the most expensive component at ~ $140 per month for a non-AZ `VpnGw1` sku including up to 128 connections, followed by the ACI container at abour $38 per month for 1 vCPU and 1 GB memory. Billing for an ACI container group uses the vCPU count rounded up to the nearest whole number - for that reason, you may as well set the CPU count to 1.

You could reduce the costs further by stopping the ACI container when not in use (e.g. over night and weekends). You could go further and delete the Gateway when not in use; but it takes a long time to recreate it, so this may not be feasible if swift access is required such as for investigating an incidient.

