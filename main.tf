

# -
# - Terraform's modules : rules of the game --> https://www.terraform.io/docs/modules/index.html
# -

# -
# - Data gathering
# -
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

locals {
  location = var.location == "" ? data.azurerm_resource_group.rg.location : var.location
  tags     = merge(var.additional_tags, data.azurerm_resource_group.rg.tags)
}

# -
# - Azure Load Balancer
# -
resource "azurerm_lb" "lbi" {
  name                = "${var.prefix}lbi${var.suffix}"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                          = "${var.prefix}lbi${var.suffix}fip001" #(Required) Specifies the name of the frontend ip configuration.
    availability_zone             = var.azurerm_lb_availability_zone      #(Optional) A list of Availability Zones which the Load Balancer's IP Addresses should be created in. Possible values are Zone-Redundant, 1, 2, 3, and No-Zone. Defaults to Zone-Redundant. No-Zones - A non-zonal resource will be created and the resource will not be replicated or distributed to any Availability Zones. 1, 2 or 3 (e.g. single Availability Zone) - A zonal resource will be created and will be replicate or distribute to a single specific Availability Zone. Zone-Redundant - A zone-redundant resource will be created and will replicate or distribute the resource across all three Availability Zones automatically.
    subnet_id                     = var.subnet_id_load_balancer           #The ID of the Subnet which should be associated with the IP Configuration.
    private_ip_address            = null                                  #(Optional) Private IP Address to assign to the Load Balancer. The last one and first four IPs in any range are reserved and cannot be manually assigned.
    private_ip_address_allocation = null                                  #(Optional) The allocation method for the Private IP Address used by this Load Balancer. Possible values as Dynamic and Static.
    private_ip_address_version    = "IPv4"                                #The version of IP that the Private IP Address is. Possible values are IPv4 or IPv6.
  }
  tags = local.tags
}

resource "azurerm_lb_probe" "lb_probe" {
  for_each            = var.forwarding_rules
  name                = "${each.key}-probe22" #(Required) Specifies the name of the Probe.
  resource_group_name = data.azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.lbi.id
  protocol            = null #(Optional) Specifies the protocol of the end point. Possible values are Http, Https or Tcp. If Tcp is specified, a received ACK is required for the probe to be successful. If Http is specified, a 200 OK response from the specified URI is required for the probe to be successful.
  port                = "22" #(Required) Port on which the Probe queries the backend endpoint. Possible values range from 1 to 65535, inclusive.
  request_path        = null #(Optional) The URI used for requesting health status from the backend endpoint. Required if protocol is set to Http or Https. Otherwise, it is not allowed.
  interval_in_seconds = 15   #(Optional) The interval, in seconds between probes to the backend endpoint for health status. The default value is 15, the minimum value is 5.
  number_of_probes    = 2    #(Optional) The number of failed probe attempts after which the backend endpoint is removed from rotation. The default value is 2. NumberOfProbes multiplied by intervalInSeconds value must be greater or equal to 10.Endpoints are returned to rotation when at least one probe is successful.
}

resource "azurerm_lb_backend_address_pool" "lb_backend_address_pool" {
  name            = "forwarder" #(Required) Specifies the name of the Backend Address Pool.
  loadbalancer_id = azurerm_lb.lbi.id
}

resource "azurerm_lb_rule" "lb_rule" {
  for_each                       = var.forwarding_rules
  name                           = each.key #(Required) Specifies the name of the LB Rule.
  resource_group_name            = data.azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lbi.id
  frontend_ip_configuration_name = "${azurerm_lb.lbi.name}fip001" #(Required) The name of the frontend IP configuration to which the rule is associated.
  protocol                       = "Tcp"                          #(Required) The transport protocol for the external endpoint. Possible values are Tcp, Udp or All.
  frontend_port                  = each.value.source_port         #(Required) The port for the external endpoint. Port numbers for each Rule must be unique within the Load Balancer. Possible values range between 0 and 65534, inclusive.
  backend_port                   = each.value.source_port         #(Required) The port used for internal connections on the endpoint. Possible values range between 0 and 65535, inclusive.
  probe_id                       = [for x in azurerm_lb_probe.lb_probe : x.id if x.name == "${each.key}-probe22"][0]
  enable_floating_ip             = null #(Optional) Are the Floating IPs enabled for this Load Balncer Rule? A "floating” IP is reassigned to a secondary server in case the primary server fails. Required to configure a SQL AlwaysOn Availability Group. Defaults to false.
  idle_timeout_in_minutes        = null #(Optional) Specifies the idle timeout in minutes for TCP connections. Valid values are between 4 and 30 minutes. Defaults to 4 minutes.
  load_distribution              = null #(Optional) Specifies the load balancing distribution type to be used by the Load Balancer. Possible values are: Default – The load balancer is configured to use a 5 tuple hash to map traffic to available servers. SourceIP – The load balancer is configured to use a 2 tuple hash to map traffic to available servers. SourceIPProtocol – The load balancer is configured to use a 3 tuple hash to map traffic to available servers. Also known as Session Persistence, where the options are called None, Client IP and Client IP and Protocol respectively.
  disable_outbound_snat          = null #(Optional) Is snat enabled for this Load Balancer Rule? Default false.
  enable_tcp_reset               = null #(Optional) Is TCP Reset enabled for this Load Balancer Rule? Defaults to false.                                                        #(Optional) The number of failed probe attempts after which the backend endpoint is removed from rotation. The default value is 2. NumberOfProbes multiplied by intervalInSeconds value must be greater or equal to 10.Endpoints are returned to rotation when at least one probe is successful.
}

# -
# - Azure Private Link Service
# -
resource "azurerm_private_link_service" "pls" {
  name                = "${var.prefix}pls${var.suffix}"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name
  nat_ip_configuration {
    name                       = "${var.prefix}pls${var.suffix}natcfg001" #(Required) Specifies the name which should be used for the NAT IP Configuration. Changing this forces a new resource to be created.
    subnet_id                  = var.subnet_id_private_link
    primary                    = true   #(Required) Is this is the Primary IP Configuration? Changing this forces a new resource to be created.
    private_ip_address         = null   #(Optional) Specifies a Private Static IP Address for this IP Configuration.
    private_ip_address_version = "IPv4" #(Optional) The version of the IP Protocol which should be used. At this time the only supported value is IPv4. Defaults to IPv4.
  }

  nat_ip_configuration {
    name                       = "${var.prefix}pls${var.suffix}natcfg002" #(Required) Specifies the name which should be used for the NAT IP Configuration. Changing this forces a new resource to be created.
    subnet_id                  = var.subnet_id_private_link
    primary                    = false  #(Required) Is this is the Primary IP Configuration? Changing this forces a new resource to be created.
    private_ip_address         = null   #(Optional) Specifies a Private Static IP Address for this IP Configuration.
    private_ip_address_version = "IPv4" #(Optional) The version of the IP Protocol which should be used. At this time the only supported value is IPv4. Defaults to IPv4.
  }
  load_balancer_frontend_ip_configuration_ids = [azurerm_lb.lbi.frontend_ip_configuration.0.id]                                                                                                                                          #(Required) A list of Frontend IP Configuration ID's from a Standard Load Balancer, where traffic from the Private Link Service should be routed. You can use Load Balancer Rules to direct this traffic to appropriate backend pools where your applications are running.
  auto_approval_subscription_ids              = var.private_link_service_auto_approval_subscription_ids[0] == "current" ? [data.azurerm_client_config.current.subscription_id] : var.private_link_service_auto_approval_subscription_ids #(Optional) A list of Subscription UUID/GUID's that will be automatically be able to use this Private Link Service.
  enable_proxy_protocol                       = null                                                                                                                                                                                     #(Optional) Should the Private Link Service support the Proxy Protocol? Defaults to false.
  visibility_subscription_ids                 = var.private_link_service_visibility_subscription_ids[0] == "current" ? [data.azurerm_client_config.current.subscription_id] : var.private_link_service_visibility_subscription_ids       #(Optional) A list of Subscription UUID/GUID's that will be able to see this Private Link Service.
  tags                                        = local.tags
}

# -
# - Azure Virtual Machine Scale Set
# -
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss_linux" {
  depends_on                                        = [azurerm_lb_probe.lb_probe, azurerm_lb_rule.lb_rule]
  name                                              = "${var.prefix}vmss${var.suffix}"
  location                                          = local.location
  resource_group_name                               = data.azurerm_resource_group.rg.name
  sku                                               = var.vmss_linux.sku
  proximity_placement_group_id                      = lookup(var.vmss_linux, "proximity_placement_group_id", null)
  admin_username                                    = lookup(var.vmss_linux, "admin_username", null)
  admin_password                                    = lookup(var.vmss_linux, "admin_password", null) == null ? random_password.password.result : var.vmss_linux.admin_password
  custom_data                                       = lookup(var.vmss_linux, "custom_data", null)
  disable_password_authentication                   = lookup(var.vmss_linux, "disable_password_authentication", false)
  encryption_at_host_enabled                        = lookup(var.vmss_linux, "encryption_at_host_enabled", null)
  eviction_policy                                   = lookup(var.vmss_linux, "eviction_policy", null)
  max_bid_price                                     = lookup(var.vmss_linux, "max_bid_price", null)
  priority                                          = lookup(var.vmss_linux, "priority", null)
  provision_vm_agent                                = lookup(var.vmss_linux, "provision_vm_agent", null)
  source_image_id                                   = lookup(var.vmss_linux, "source_image_id", null)
  instances                                         = lookup(var.vmss_linux, "instances", null)
  computer_name_prefix                              = lookup(var.vmss_linux, "computer_name_prefix", null)
  do_not_run_extensions_on_overprovisioned_machines = lookup(var.vmss_linux, "do_not_run_extensions_on_overprovisioned_machines", null)
  health_probe_id                                   = [for x in azurerm_lb_probe.lb_probe : x.id][0]
  overprovision                                     = lookup(var.vmss_linux, "overprovision", null)
  scale_in_policy                                   = lookup(var.vmss_linux, "scale_in_policy", null)
  single_placement_group                            = lookup(var.vmss_linux, "single_placement_group", null)
  upgrade_mode                                      = lookup(var.vmss_linux, "upgrade_mode", null)
  zone_balance                                      = lookup(var.vmss_linux, "zone_balance", null)
  zones                                             = lookup(var.vmss_linux, "zones", null)

  dynamic "network_interface" {
    for_each = var.vmss_linux.network_interfaces
    content {
      name                          = "${var.prefix}nic${var.suffix}"
      dns_servers                   = lookup(network_interface.value, "dns_servers", null)
      enable_accelerated_networking = lookup(network_interface.value, "enable_accelerated_networking", false)
      enable_ip_forwarding          = lookup(network_interface.value, "enable_ip_forwarding", false)
      network_security_group_id     = lookup(network_interface.value, "network_security_group_id", null)
      primary                       = lookup(network_interface.value, "primary", false)

      ip_configuration {
        name                                         = "${var.prefix}nic${var.suffix}cfg"
        application_gateway_backend_address_pool_ids = lookup(network_interface.value, "application_gateway_backend_address_pool_ids", null)
        application_security_group_ids               = lookup(network_interface.value, "application_security_group_ids", [])
        load_balancer_backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend_address_pool.id]
        load_balancer_inbound_nat_rules_ids          = lookup(network_interface.value, "load_balancer_inbound_nat_rules_ids", [])
        primary                                      = lookup(network_interface.value, "primary", false)
        subnet_id                                    = var.subnet_id_virtual_machine_scale_set

        dynamic "public_ip_address" {
          for_each = lookup(network_interface.value, "public_ip_address", [])
          content {
            name                    = "${var.prefix}pip${public_ip_address.value["instance"]}"
            domain_name_label       = lookup(public_ip_address.value, "domain_name_label", null)
            idle_timeout_in_minutes = lookup(public_ip_address.value, "idle_timeout_in_minutes", null)
            public_ip_prefix_id     = lookup(public_ip_address.value, "public_ip_prefix_id", null)

            dynamic "ip_tag" {
              for_each = lookup(network_interface.value.public_ip_address, "ip_tag", [])
              content {
                type = ip_tag.value.type
                tag  = ip_tag.value.tag
              }
            }
          }
        }
      }
    }
  }

  os_disk {
    caching                   = lookup(var.vmss_linux.os_disk, "caching", "None")
    storage_account_type      = lookup(var.vmss_linux.os_disk, "storage_account_type", "Standard_LRS")
    disk_encryption_set_id    = lookup(var.vmss_linux.os_disk, "disk_encryption_set_id", null)
    disk_size_gb              = lookup(var.vmss_linux.os_disk, "disk_size_gb", null)
    write_accelerator_enabled = lookup(var.vmss_linux.os_disk, "write_accelerator_enabled", null)

    dynamic "diff_disk_settings" {
      for_each = lookup(var.vmss_linux.os_disk, "diff_disk_settings", [])
      content {
        option = lookup(diff_disk_settings.value, "option", "Local")
      }
    }
  }

  dynamic "additional_capabilities" {
    for_each = lookup(var.vmss_linux, "additional_capabilities", [])
    content {
      ultra_ssd_enabled = lookup(additional_capabilities.value, "ultra_ssd_enabled", false)
    }
  }

  dynamic "automatic_os_upgrade_policy" {
    for_each = lookup(var.vmss_linux, "automatic_os_upgrade_policy", [])
    content {
      disable_automatic_rollback  = automatic_os_upgrade_policy.value.disable_automatic_rollback
      enable_automatic_os_upgrade = automatic_os_upgrade_policy.value.enable_automatic_os_upgrade
    }
  }

  dynamic "automatic_instance_repair" {
    for_each = lookup(var.vmss_linux, "automatic_instance_repair", [])
    content {
      enabled      = lookup(automatic_instance_repair.value, "enabled", false)
      grace_period = lookup(automatic_instance_repair.value, "grace_period", 30)
    }
  }

  dynamic "data_disk" {
    for_each = lookup(var.vmss_linux, "data_disk", [])
    content {
      caching                   = lookup(data_disk.value, "caching", "None")
      create_option             = lookup(data_disk.value, "create_option", "Empty")
      storage_account_type      = lookup(data_disk.value, "storage_account_type", "Standard_LRS")
      disk_encryption_set_id    = lookup(data_disk.value, "disk_encryption_set_id", null)
      disk_size_gb              = data_disk.value.disk_size_gb
      lun                       = data_disk.value.lun
      write_accelerator_enabled = lookup(data_disk.value, "write_accelerator_enabled", null)
    }
  }

  dynamic "extension" {
    for_each = lookup(var.vmss_linux, "extension", [])
    content {
      name                       = extension.value.name
      publisher                  = extension.value.publisher
      type                       = extension.value.type
      type_handler_version       = extension.value.type_handler_version
      auto_upgrade_minor_version = lookup(extension.value, "auto_upgrade_minor_version", false)
      force_update_tag           = lookup(extension.value, "force_update_tag", null)
      protected_settings         = lookup(extension.value, "protected_settings", null)
      provision_after_extensions = lookup(extension.value, "provision_after_extensions", null)
      settings                   = lookup(extension.value, "settings", null)
    }
  }

  dynamic "plan" {
    for_each = lookup(var.vmss_linux, "plan", [])
    content {
      name      = plan.value.name
      publisher = plan.value.publisher
      product   = plan.value.product
    }
  }

  dynamic "rolling_upgrade_policy" {
    for_each = lookup(var.vmss_linux, "rolling_upgrade_policy", [])
    content {
      max_batch_instance_percent              = rolling_upgrade_policy.value.max_batch_instance_percent
      max_unhealthy_instance_percent          = rolling_upgrade_policy.value.max_unhealthy_instance_percent
      max_unhealthy_upgraded_instance_percent = rolling_upgrade_policy.value.max_unhealthy_upgraded_instance_percent
      pause_time_between_batches              = rolling_upgrade_policy.value.pause_time_between_batches
    }
  }

  dynamic "secret" {
    for_each = lookup(var.vmss_linux, "secret", [])
    content {
      key_vault_id = secret.value.key_vault_id
      dynamic "certificate" {
        for_each = lookup(secret.value, "certificate", null) == null ? [] : secret.value.certificate
        content {
          url = certificate.value.url
        }
      }
    }
  }

  dynamic "source_image_reference" {
    for_each = lookup(var.vmss_linux, "source_image_reference", [])
    content {
      publisher = source_image_reference.value.publisher
      offer     = source_image_reference.value.offer
      sku       = source_image_reference.value.sku
      version   = source_image_reference.value.version
    }
  }

  dynamic "terminate_notification" {
    for_each = lookup(var.vmss_linux, "terminate_notification", [])
    content {
      enabled = lookup(terminate_notification.value, "enabled", false)
      timeout = lookup(terminate_notification.value, "timeout", null)
    }
  }

  tags = local.tags
  // Ignore changes that are managed outside Terraform
  lifecycle {
    ignore_changes = [
      instances
    ]
  }
}

locals {
  vmss_linux_extension_settings = {
    commandToExecute = join(" && ", [for x in var.forwarding_rules : "sudo ./ip_fwd.sh -i eth0 -f ${x.source_port} -a ${x.destination_address} -b ${x.destination_port}"])
    fileUris         = ["https://raw.githubusercontent.com/sajitsasi/az-ip-fwd/cc2caaad627e90dcf75b751169bd0cac251223d3/ip_fwd.sh"]
  }
}

resource "azurerm_virtual_machine_scale_set_extension" "vmss_linux" {
  name                         = "forwarder"
  virtual_machine_scale_set_id = azurerm_linux_virtual_machine_scale_set.vmss_linux.id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.0"
  settings                     = jsonencode(local.vmss_linux_extension_settings)
}
