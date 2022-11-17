#Call native Terraform resources
data "azurerm_resource_group" "rg" {
  name = "hashicorp-privatelink-noprd-rg1"
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

#Call module
module "Az-PrivateLinkForNonAzureResources-Demo" {
  source                              = "JamesDLD/Az-PrivateLinkForNonAzureResources/azurerm"
  version                             = "0.2.0"
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

#Azure Bastion
resource "azurerm_public_ip" "Demo-bastion" {
  name                = "demo-azure-bastion-pip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "Demo" {
  name                   = "demo-azure-bastion"
  location               = data.azurerm_resource_group.rg.location
  resource_group_name    = data.azurerm_resource_group.rg.name
  copy_paste_enabled     = true
  file_copy_enabled      = true
  shareable_link_enabled = true
  sku                    = "Standard"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.Demo["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.Demo-bastion.id
  }
}

#NAT Gateway
resource "azurerm_public_ip" "Demo-nat-gateway" {
  name                = "demo-nat-gateway-pip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_nat_gateway" "Demo" {
  name                    = "demo-nat-gateway"
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

# SFTP
resource "azurerm_storage_account" "Demo" {
  name                            = "demoprivatelinksftp"
  resource_group_name             = "module-private-link-noprd-rg1"
  location                        = data.azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  is_hns_enabled                  = true
  allow_nested_items_to_be_public = false
}

# Workaround until azurerm_storage_account supports isSftpEnabled property
# see https://github.com/hashicorp/terraform-provider-azurerm/issues/14736
resource "azapi_update_resource" "Demo-enable-sftp" {
  type        = "Microsoft.Storage/storageAccounts@2021-09-01"
  resource_id = azurerm_storage_account.Demo.id

  body = jsonencode({
    properties = {
      isSftpEnabled = true
    }
  })
}

# Web App
resource "azurerm_service_plan" "Demo" {
  name                = "demoprivatelinkweb"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku_name            = "F1"
  os_type             = "Windows"
}

resource "azurerm_windows_web_app" "Demo" {
  name                = "demoprivatelinkweb"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = azurerm_service_plan.Demo.location
  service_plan_id     = azurerm_service_plan.Demo.id
  https_only          = true

  site_config {
    always_on = false
    virtual_application {
      physical_path = "site\\wwwroot"
      preload       = false
      virtual_path  = "/"
    }

    ip_restriction {
      action     = "Deny"
      ip_address = "4.231.41.18/32"
      name       = "nat-gateway-of-the-private-link"
    }
  }
}