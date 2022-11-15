Test
-----
[![Build Status](https://dev.azure.com/jamesdld23/vpc_lab/_apis/build/status/Terraform%20module%20Az-PrivateLinkForNonAzureResources?repoName=JamesDLD%2Fterraform-azurerm-Az-PrivateLinkForNonAzureResources&branchName=main)](https://dev.azure.com/jamesdld23/vpc_lab/_build/latest?definitionId=20&repoName=JamesDLD%2Fterraform-azurerm-Az-PrivateLinkForNonAzureResources&branchName=main)

Content
-----
Use cases described in the following
article : [Access to any non Azure resources with an Azure Private Link (Terraform module)](https://medium.com/@jamesdld23/access-to-any-non-azure-resources-with-an-azure-private-link-b6129992dad9)
.
This module has been used during a french Hashicorp meetup on november 17th,
2022: [[HUG] Meetup Paris #17 - Novembre 2022](https://www.meetup.com/fr-FR/Hashicorp-User-Group-Paris/events/289541806/?utm_medium=email&utm_source=braze_canvas&utm_campaign=mmrk_alleng_event_announcement_prod_v7_fr&utm_term=promo&utm_content=lp_meetup)

Requirement
-----
Terraform v1.3.4 and above.
AzureRm provider version v2.81.0 and above.

Usage
-----

```hcl
#Set the terraform backend
terraform {
  backend "local" {}
  #Using a local backend just for the demo, the reco is to use a remote backend, see : https://jamesdld.github.io/terraform/Best-Practice/BestPractice-1/
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
  }
}

#Set the Provider
provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

provider "azapi" {
}

variable "subscription_id" {
  description = "Azure subscription Id."
}

#Set resource variables
variable "additional_tags" {
  default = {
    iac = "terraform"
  }
}

variable "forwarding_rules" {
  description = "Forwarding Rule to Endpoint (cf https://docs.microsoft.com/en-us/azure/data-factory/tutorial-managed-virtual-network-on-premise-sql-server?WT.mc_id=AZ-MVP-5003548&WT.mc_id=AZ-MVP-5003548#creating-forwarding-rule-to-endpoint)."
  type = any
  default = {
    "demo-static-website" = {
      source_port = "443"
      destination_address = "demoprivatelinksftp.blob.core.windows.net"
      destination_port = "443"
    }
    "demo-sftp" = {
      source_port = "223"
      destination_address = "demoprivatelinksftp.blob.core.windows.net"
      destination_port = "22"
    }
  }
}

variable "virtual_network" {
  default = {
    name = "hashicorp-privatelink-npd-vnet4"
    address_space = ["10.0.128.0/24", "198.18.2.0/24"]
    subnets = {
      privatelink = {
        address_prefixes = ["10.0.128.0/28"]
        private_link_service_network_policies_enabled = false
      }

      loadbalancer = {
        address_prefixes = ["10.0.128.16/28"]
      }

      compute = {
        address_prefixes = ["10.0.128.32/28"]
      }

      AzureBastionSubnet = {
        address_prefixes = ["198.18.2.0/26"]
      }
    }
  }
}

#Call native Terraform resources
data "azurerm_resource_group" "rg" {
  name = "hashicorp-privatelink-noprd-rg1"
}

resource "azurerm_virtual_network" "Demo" {
  name = var.virtual_network.name
  location = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space = var.virtual_network.address_space
  tags = data.azurerm_resource_group.rg.tags
}

resource "azurerm_subnet" "Demo" {
  for_each = var.virtual_network.subnets
  name = each.key
  resource_group_name = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.Demo.name
  address_prefixes = each.value.address_prefixes
  private_link_service_network_policies_enabled = lookup(each.value, "private_link_service_network_policies_enabled", null)
  #(Optional) Enable or Disable network policies for the private link service on the subnet. Default valule is false. Conflicts with enforce_private_link_endpoint_network_policies.
}

#Call module
module "Az-PrivateLinkForNonAzureResources-Demo" {
  source = "JamesDLD/Az-PrivateLinkForNonAzureResources/azurerm"
  version = "0.2.0"
  location = data.azurerm_resource_group.rg.location
  additional_tags = var.additional_tags
  prefix = "demo"
  suffix = "1"
  resource_group_name = data.azurerm_resource_group.rg.name
  subnet_id_private_link = azurerm_subnet.Demo["privatelink"].id
  subnet_id_load_balancer = azurerm_subnet.Demo["loadbalancer"].id
  subnet_id_virtual_machine_scale_set = azurerm_subnet.Demo["compute"].id
  forwarding_rules = var.forwarding_rules
}

#Azure Bastion
resource "azurerm_public_ip" "Demo-bastion" {
  name = "demo-azure-bastion-pip"
  location = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method = "Static"
  sku = "Standard"
}

resource "azurerm_bastion_host" "Demo" {
  name = "demo-azure-bastion"
  location = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  copy_paste_enabled = true
  file_copy_enabled = true
  shareable_link_enabled = true
  sku = "Standard"

  ip_configuration {
    name = "configuration"
    subnet_id = azurerm_subnet.Demo["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.Demo-bastion.id
  }
}

#NAT Gateway
resource "azurerm_public_ip" "Demo-nat-gateway" {
  name = "demo-nat-gateway-pip"
  location = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method = "Static"
  sku = "Standard"
  zones = ["1"]
}

resource "azurerm_nat_gateway" "Demo" {
  name = "demo-nat-gateway"
  location = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku_name = "Standard"
  idle_timeout_in_minutes = 10
  zones = ["1"]
}

resource "azurerm_nat_gateway_public_ip_association" "Demo" {
  nat_gateway_id = azurerm_nat_gateway.Demo.id
  public_ip_address_id = azurerm_public_ip.Demo-nat-gateway.id
}

resource "azurerm_subnet_nat_gateway_association" "Demo-Subnet-compute" {
  subnet_id = azurerm_subnet.Demo["compute"].id
  nat_gateway_id = azurerm_nat_gateway.Demo.id
}

# SFTP
resource "azurerm_storage_account" "Demo" {
  name = "demoprivatelinksftp"
  resource_group_name = "module-private-link-noprd-rg1"
  location = data.azurerm_resource_group.rg.location
  account_tier = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled = true
  allow_nested_items_to_be_public = false
}

# Workaround until azurerm_storage_account supports isSftpEnabled property
# see https://github.com/hashicorp/terraform-provider-azurerm/issues/14736
resource "azapi_update_resource" "Demo-enable-sftp" {
  type = "Microsoft.Storage/storageAccounts@2021-09-01"
  resource_id = azurerm_storage_account.Demo.id

  body = jsonencode({
    properties = {
      isSftpEnabled = true
    }
  })
}
```