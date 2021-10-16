variable "location" {
  description = "(Optional) Resources location if different that the resource group's location."
  type        = string
  default     = ""
}

variable "additional_tags" {
  description = "(Optional) Resources tags to add on all resources."
  type        = map(string)
  default     = {}
}

variable "prefix" {
  description = "(Optional) Prefix used for all resources names."
  default     = ""
  type        = string
}

variable "suffix" {
  description = "(Optional) Suffix used for all resources names."
  default     = ""
  type        = string
}

variable "resource_group_name" {
  description = "(Required) The resource group name of the Private Link resources."
  type        = string
}

variable "subnet_id_private_link" {
  description = "(Required) Subnet id of the Private Link service."
  type        = string
}

variable "subnet_id_load_balancer" {
  description = "(Required) Subnet id of the Private Link Load Balancer."
  type        = string
}

variable "subnet_id_virtual_machine_scale_set" {
  description = "(Required) Subnet id of the Private Link Virtual Machine Scale Set."
  type        = string
}

variable "forwarding_rules" {
  description = "(Required) Forwarding Rules to Endpoints (cf https://docs.microsoft.com/en-us/azure/data-factory/tutorial-managed-virtual-network-on-premise-sql-server?WT.mc_id=AZ-MVP-5003548&WT.mc_id=AZ-MVP-5003548#creating-forwarding-rule-to-endpoint)."
  type        = any
}

variable "private_link_service_visibility_subscription_ids" {
  description = "(Optional) A list of Subscription UUID/GUID's that will be able to see this Private Link Service."
  type        = list(any)
  default     = ["current"]
}
variable "private_link_service_auto_approval_subscription_ids" {
  description = "(Optional) A list of Subscription UUID/GUID's that will be automatically be able to use this Private Link Service."
  type        = list(any)
  default     = ["current"]
}
variable "azurerm_lb_availability_zone" {
  description = "(Optional) A list of Availability Zones which the Load Balancer's IP Addresses should be created in. Possible values are Zone-Redundant, 1, 2, 3, and No-Zone. Availability Zone can only be updated whenever the name of the front end ip configuration changes. Defaults to Zone-Redundant. No-Zones - A non-zonal resource will be created and the resource will not be replicated or distributed to any Availability Zones."
  type        = string
  default     = null
}

variable "vmss_linux" {
  description = "(Optional) The Virtual Machine Scale Set."
  type        = any
  default = {
    sku          = "standard_f1s"
    upgrade_mode = "Automatic"
    automatic_os_upgrade_policy = [
      {
        disable_automatic_rollback  = false
        enable_automatic_os_upgrade = true
      }
    ]
    admin_username = "demonatadm"
    instances      = 2
    source_image_reference = [{
      publisher = "Canonical"
      offer     = "UbuntuServer" #Find specific images : az vm image list --offer UbuntuServer --all --output table 
      sku       = "18.04-LTS"
      version   = "latest"
    }]
    network_interfaces = [{
      enable_accelerated_networking = true
      primary                       = true
      load_balancer_backend_address_pool_ids = [
        {
          lb_backend_address_pool_key = "forwarder"
        }
      ]
    }]
    os_disk = {
      caching = "ReadOnly"
    }
  }
}
