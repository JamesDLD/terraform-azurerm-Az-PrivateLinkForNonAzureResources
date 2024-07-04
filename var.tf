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

variable "virtual_machine_scale_set_name" {
  description = "(Optional) Virtual Machine scale set name."
  default     = ""
  type        = string
}

variable "private_link_service_name" {
  description = "(Optional) Private Link service name."
  default     = ""
  type        = string
}

variable "lb_name" {
  description = "(Optional) Load balancer name."
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

variable "lb_probe_default_specification" {
  description = "Load Balancer default specifications"
  type        = any
  default = {
    protocol            = null
    request_path        = null
    interval_in_seconds = 15
    number_of_probes    = 2
  }
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
  description = "(Optional) A list of Availability Zones which the Load Balancer's IP Addresses should be created in."
  type        = list(any)
  default     = ["1", "2", "3"]
}

variable "vmss_linux" {
  description = "(Optional) The Virtual Machine Scale Set."
  type        = any
  default = {
    sku          = "standard_f1s" //"Standard_DS1_v2" #Supports Enabling Accelerated Networking For Vmss
    upgrade_mode = "Automatic"
    automatic_os_upgrade_policy = [
      {
        disable_automatic_rollback  = false
        enable_automatic_os_upgrade = true
      }
    ]
    rolling_upgrade_policy = [
      {
        max_batch_instance_percent              = 20
        max_unhealthy_instance_percent          = 20
        max_unhealthy_upgraded_instance_percent = 20
        pause_time_between_batches              = "PT0S"
      }
    ]
    automatic_os_upgrade_policy = [
      {
        disable_automatic_rollback  = false
        enable_automatic_os_upgrade = true
      }
    ]
    admin_username = "demonatadm"
    instances      = 2
    source_image_reference = [
      {
        publisher = "Canonical"
        offer     = "0001-com-ubuntu-server-jammy" #Find specific images : az vm image list --offer 0001-com-ubuntu-server-jammy --all --output table
        sku       = "22_04-lts-gen2"
        version   = "latest"
      }
    ]
    network_interfaces = [
      {
        enable_accelerated_networking = true
        primary                       = true
        load_balancer_backend_address_pool_ids = [
          {
            lb_backend_address_pool_key = "forwarder"
          }
        ]
      }
    ]
    os_disk = {
      caching = "ReadOnly"
    }
  }
}

variable "vmss_linux_admin" {
  description = "Virtual Machine Scale Set credential option"
  default = {
    admin_username       = "none"
    admin_ssh_public_key = "none"
  }
}
