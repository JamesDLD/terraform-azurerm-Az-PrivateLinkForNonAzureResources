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
    zones                         = var.azurerm_lb_availability_zone
    subnet_id                     = var.subnet_id_load_balancer
    private_ip_address            = null
    private_ip_address_allocation = null
    private_ip_address_version    = "IPv4"
  }
  tags = local.tags
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_lb_probe" "lb_probe_vmss" {
  name                = "vmss-probe22"
  loadbalancer_id     = azurerm_lb.lbi.id
  protocol            = null
  port                = 22
  request_path        = null
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_probe" "lb_probe" {
  for_each            = var.forwarding_rules
  name                = "${each.key}-probe${each.value.source_port}"
  loadbalancer_id     = azurerm_lb.lbi.id
  protocol            = null
  port                = each.value.source_port
  request_path        = null
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_backend_address_pool" "lb_backend_address_pool_vmss" {
  name            = "forwarder-vmss-probed-on-22" #(Required) Specifies the name of the Backend Address Pool.
  loadbalancer_id = azurerm_lb.lbi.id
}

resource "azurerm_lb_rule" "lb_rule" {
  for_each                       = var.forwarding_rules
  name                           = each.key
  loadbalancer_id                = azurerm_lb.lbi.id
  frontend_ip_configuration_name = "${azurerm_lb.lbi.name}fip001"
  protocol                       = "Tcp"
  frontend_port                  = each.value.source_port
  backend_port                   = each.value.source_port
  probe_id                       = lookup(each.value, "use_vmss_probe", null) == true ? azurerm_lb_probe.lb_probe_vmss.id : azurerm_lb_probe.lb_probe[each.key].id
  enable_floating_ip             = null
  idle_timeout_in_minutes        = null
  load_distribution              = null
  disable_outbound_snat          = null
  enable_tcp_reset               = null
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend_address_pool_vmss.id]
}

resource "azurerm_lb_rule" "lb_rule_vmss" {
  name                           = "vmss"
  loadbalancer_id                = azurerm_lb.lbi.id
  frontend_ip_configuration_name = "${azurerm_lb.lbi.name}fip001"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  probe_id                       = azurerm_lb_probe.lb_probe_vmss.id
  enable_floating_ip             = null
  idle_timeout_in_minutes        = null
  load_distribution              = null
  disable_outbound_snat          = null
  enable_tcp_reset               = null
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend_address_pool_vmss.id]
}

# -
# - Azure Private Link Service
# -
resource "azurerm_private_link_service" "pls" {
  name                = "${var.prefix}pls${var.suffix}"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.rg.name
  nat_ip_configuration {
    name                       = "${var.prefix}pls${var.suffix}natcfg001"
    subnet_id                  = var.subnet_id_private_link
    primary                    = true
    private_ip_address         = null #(Optional) Specifies a Private Static IP Address for this IP Configuration.
    private_ip_address_version = "IPv4"
  }

  nat_ip_configuration {
    name                       = "${var.prefix}pls${var.suffix}natcfg002"
    subnet_id                  = var.subnet_id_private_link
    primary                    = false
    private_ip_address         = null #(Optional) Specifies a Private Static IP Address for this IP Configuration.
    private_ip_address_version = "IPv4"
  }
  load_balancer_frontend_ip_configuration_ids = [azurerm_lb.lbi.frontend_ip_configuration.0.id]
  auto_approval_subscription_ids = var.private_link_service_auto_approval_subscription_ids[0] == "current" ? [
    data.azurerm_client_config.current.subscription_id
  ] : var.private_link_service_auto_approval_subscription_ids
  enable_proxy_protocol = null
  visibility_subscription_ids = var.private_link_service_visibility_subscription_ids[0] == "current" ? [
    data.azurerm_client_config.current.subscription_id
  ] : var.private_link_service_visibility_subscription_ids
  tags = local.tags
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
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
  depends_on = [
    azurerm_lb_probe.lb_probe, azurerm_lb_probe.lb_probe_vmss, azurerm_lb_rule.lb_rule, azurerm_lb_rule.lb_rule_vmss,
    azurerm_lb_backend_address_pool.lb_backend_address_pool_vmss
  ]
  name                                              = "${var.prefix}vmss${var.suffix}"
  location                                          = local.location
  resource_group_name                               = data.azurerm_resource_group.rg.name
  sku                                               = var.vmss_linux.sku
  proximity_placement_group_id                      = lookup(var.vmss_linux, "proximity_placement_group_id", null)
  admin_username                                    = var.vmss_linux_admin.admin_username == "none" ? lookup(var.vmss_linux, "admin_username", null) : var.vmss_linux_admin.admin_username
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
  health_probe_id                                   = azurerm_lb_probe.lb_probe_vmss.id
  overprovision                                     = lookup(var.vmss_linux, "overprovision", null)
  dynamic "scale_in" {
    for_each = lookup(var.vmss_linux, "scale_in", [])
    content {
      rule                   = lookup(scale_in.value, "rule", null)
      force_deletion_enabled = lookup(scale_in.value, "force_deletion_enabled", null)
    }
  }
  single_placement_group = lookup(var.vmss_linux, "single_placement_group", null)
  upgrade_mode           = lookup(var.vmss_linux, "upgrade_mode", null)
  zone_balance           = lookup(var.vmss_linux, "zone_balance", null)
  zones                  = lookup(var.vmss_linux, "zones", null)

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
        load_balancer_backend_address_pool_ids = [
          azurerm_lb_backend_address_pool.lb_backend_address_pool_vmss.id
        ]
        load_balancer_inbound_nat_rules_ids = lookup(network_interface.value, "load_balancer_inbound_nat_rules_ids", [])
        primary                             = lookup(network_interface.value, "primary", false)
        subnet_id                           = var.subnet_id_virtual_machine_scale_set

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

  dynamic "admin_ssh_key" {
    for_each = var.vmss_linux_admin.admin_ssh_public_key == "none" ? [] : [{}]
    content {
      public_key = var.vmss_linux_admin.admin_ssh_public_key
      username   = var.vmss_linux_admin.admin_username
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

  dynamic "termination_notification" {
    for_each = lookup(var.vmss_linux, "termination_notification", [])
    content {
      enabled = lookup(termination_notification.value, "enabled", false)
      timeout = lookup(termination_notification.value, "timeout", null)
    }
  }

  tags = local.tags
  // Ignore changes that are managed outside Terraform
  lifecycle {
    ignore_changes = [
      tags,
      instances
    ]
  }
}

locals {
  vmss_linux_extension_settings = {
    commandToExecute = join(" && ", [for x in var.forwarding_rules : "sudo ./ip_fwd.sh -i eth0 -f ${x.source_port} -a ${x.destination_address} -b ${x.destination_port}"])
    fileUris = [
      "https://raw.githubusercontent.com/sajitsasi/az-ip-fwd/cc2caaad627e90dcf75b751169bd0cac251223d3/ip_fwd.sh"
    ]
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
