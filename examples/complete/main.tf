#Set the terraform backend
terraform {
  backend "local" {} #Using a local backend just for the demo, the reco is to use a remote backend, see : https://jamesdld.github.io/terraform/Best-Practice/BestPractice-1/
}

#Set the Provider
provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

#Call module
module "Az-PrivateLinkForNonAzureResources-Demo" {
  source   = "JamesDLD/Az-PrivateLinkForNonAzureResources/azurerm"
  version  = "0.1.0"
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
