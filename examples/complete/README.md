Content
-----
Use cases described in the following article : [Access to any non Azure resources with an Azure Private Link (Terraform module)](https://medium.com/@jamesdld23/access-to-any-non-azure-resources-with-an-azure-private-link-b6129992dad9).
This module will create the following objects : 

- [Azure Private Link Service](https://docs.microsoft.com/en-us/azure/private-link/private-link-service-overview?WT.mc_id=AZ-MVP-5003548)
- [Azure Standard Load Balancer](https://docs.microsoft.com/en-us/azure/private-link/create-private-link-service-portal?WT.mc_id=AZ-MVP-5003548#create-an-internal-load-balancer)
- [Azure Virtual Machine Scale Set with forwarding rules](https://docs.microsoft.com/en-us/azure/data-factory/tutorial-managed-virtual-network-on-premise-sql-server?WT.mc_id=AZ-MVP-5003548#creating-forwarding-rule-to-endpoint)

Requirement
-----
Terraform v1.0.6 and above. 
AzureRm provider version v2.81.0 and above.

Usage
-----
```hcl
#Set the terraform backend
terraform {
  backend "local" {} #Using a local backend just for the demo, the reco is to use a remote backend, see : https://jamesdld.github.io/terraform/Best-Practice/BestPractice-1/
}

#Set the Provider
provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

variable "subscription_id" {
  description = "Azure subscription Id."
}

#Set variable
variable "forwarding_rules" {
  description = "Forwarding Rule to Endpoint (cf https://docs.microsoft.com/en-us/azure/data-factory/tutorial-managed-virtual-network-on-premise-sql-server?WT.mc_id=AZ-MVP-5003548&WT.mc_id=AZ-MVP-5003548#creating-forwarding-rule-to-endpoint)."
  type        = any
  default = {
    "sql-demo1" = {
      source_port         = "1433"
      destination_address = "sql1.dld23.com"
      destination_port    = "1433"
    }
    "sql-demo2" = {
      source_port         = "1434"
      destination_address = "sql2.dld23.com"
      destination_port    = "1433"
    }
    "sftp-demo1" = {
      source_port         = "221"
      destination_address = "sftp.dld23.com"
      destination_port    = "22"
    }
  }
}

#Call module
module "Az-PrivateLinkForNonAzureResources-Demo" {
  source   = "JamesDLD/Az-PrivateLinkForNonAzureResources/azurerm"
  location = "westeurope"
  additional_tags = {
    usage = "demo"
  }
  prefix                              = "dlddemo"
  suffix                              = "001"
  resource_group_name                 = "xxxxxxxxxxxxxx"
  subnet_id_private_link              = "/subscriptions/xxxxxxxxxxxxxx/resourceGroups/xxxxxxxxxxxxxx/providers/Microsoft.Network/virtualNetworks/xxxxxxxxxxxxxx/subnets/xxxxxxxxxxxxxxsub1"
  subnet_id_load_balancer             = "/subscriptions/xxxxxxxxxxxxxx/resourceGroups/xxxxxxxxxxxxxx/providers/Microsoft.Network/virtualNetworks/xxxxxxxxxxxxxx/subnets/xxxxxxxxxxxxxxsub2"
  subnet_id_virtual_machine_scale_set = "/subscriptions/xxxxxxxxxxxxxx/resourceGroups/xxxxxxxxxxxxxx/providers/Microsoft.Network/virtualNetworks/xxxxxxxxxxxxxx/subnets/xxxxxxxxxxxxxxsub3"
  forwarding_rules                    = var.forwarding_rules
}

output "azurerm_lb_id" {
  value = module.Az-PrivateLinkForNonAzureResources-Demo.lb_id
}

output "azurerm_linux_virtual_machine_scale_set_id" {
  value = module.Az-PrivateLinkForNonAzureResources-Demo.linux_virtual_machine_scale_set_id
}

output "azurerm_private_link_service_id" {
  value = module.Az-PrivateLinkForNonAzureResources-Demo.private_link_service_id
}


```