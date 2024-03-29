#Set the terraform backend
terraform {
  backend "azurerm" {
    storage_account_name = "infrasdbx1vpcjdld1"
    container_name       = "tfstate"
    key                  = "Az-PrivateLinkForNonAzureResources-Recette-Complete.master.tfstate"
    resource_group_name  = "infr-jdld-noprd-rg1"
  }
}

#Set the Provider
provider "azurerm" {
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  features {}
}

#Call native Terraform resources
data "azurerm_resource_group" "rg" {
  name = "module-private-link-noprd-rg1"
}

resource "azurerm_virtual_network" "Demo" {
  name                = var.virtual_network.name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = var.virtual_network.address_space
  tags                = data.azurerm_resource_group.rg.tags
}

resource "azurerm_subnet" "Demo" {
  for_each                                      = var.virtual_network.subnets
  name                                          = each.key
  resource_group_name                           = data.azurerm_resource_group.rg.name
  virtual_network_name                          = azurerm_virtual_network.Demo.name
  address_prefixes                              = each.value.address_prefixes
  private_link_service_network_policies_enabled = lookup(each.value, "private_link_service_network_policies_enabled", null)
  #(Optional) Enable or Disable network policies for the private link service on the subnet. Default valule is false. Conflicts with enforce_private_link_endpoint_network_policies.
}

#NAT Gateway
resource "azurerm_public_ip" "Demo-nat-gateway" {
  name                = "module-private-link-nat-gateway-pip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_nat_gateway" "Demo" {
  name                    = "module-private-link-nat-gateway"
  location                = data.azurerm_resource_group.rg.location
  resource_group_name     = data.azurerm_resource_group.rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = ["1"]
}

resource "azurerm_nat_gateway_public_ip_association" "Demo" {
  nat_gateway_id       = azurerm_nat_gateway.Demo.id
  public_ip_address_id = azurerm_public_ip.Demo-nat-gateway.id
}

resource "azurerm_subnet_nat_gateway_association" "Demo-Subnet-compute" {
  subnet_id      = azurerm_subnet.Demo["compute"].id
  nat_gateway_id = azurerm_nat_gateway.Demo.id
}

#Call module
module "Az-PrivateLinkForNonAzureResources-Demo" {
  source = "git::https://github.com/JamesDLD/terraform-azurerm-Az-PrivateLinkForNonAzureResources.git//?ref=main"
  #source = "git::https://github.com/JamesDLD/terraform-azurerm-Az-PrivateLinkForNonAzureResources.git//?ref=release/0.2.0"
  #source = "../../../"
  #source   = "JamesDLD/Az-PrivateLinkForNonAzureResources/azurerm"
  #version  = "0.2.0"
  location                            = data.azurerm_resource_group.rg.location
  additional_tags                     = var.additional_tags
  prefix                              = "demo"
  suffix                              = "1"
  resource_group_name                 = data.azurerm_resource_group.rg.name
  subnet_id_private_link              = azurerm_subnet.Demo["privatelink"].id
  subnet_id_load_balancer             = azurerm_subnet.Demo["loadbalancer"].id
  subnet_id_virtual_machine_scale_set = azurerm_subnet.Demo["compute"].id
  forwarding_rules                    = var.forwarding_rules
}
