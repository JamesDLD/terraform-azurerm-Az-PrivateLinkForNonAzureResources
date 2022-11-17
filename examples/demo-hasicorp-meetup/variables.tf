#Set authentication variables
variable "tenant_id" {
  description = "Azure tenant Id."
}

variable "subscription_id" {
  description = "Azure subscription Id."
}

variable "client_id" {
  description = "Azure service principal application Id."
}

variable "client_secret" {
  description = "Azure service principal application Secret."
}
#Set resource variables
variable "additional_tags" {
  default = {
    iac = "terraform"
  }
}

variable "virtual_network" {
  default = {
    name          = "hashicorp-privatelink-npd-vnet4"
    address_space = ["10.0.128.0/24", "198.18.2.0/24"]
    subnets = {
      privatelink = {
        address_prefixes                              = ["10.0.128.0/28"]
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

variable "forwarding_rules" {
  description = "Forwarding Rule to Endpoint (cf https://docs.microsoft.com/en-us/azure/data-factory/tutorial-managed-virtual-network-on-premise-sql-server?WT.mc_id=AZ-MVP-5003548&WT.mc_id=AZ-MVP-5003548#creating-forwarding-rule-to-endpoint)."
  type        = any
  default = {
    "demo-website" = {
      source_port         = "8000"
      destination_address = "demoprivatelinkweb.azurewebsites.net"
      destination_port    = "443"
      use_vmss_probe      = true
    }
    "demo-sftp" = {
      source_port         = "223"
      destination_address = "demoprivatelinksftp.blob.core.windows.net"
      destination_port    = "22"
    }
  }
}