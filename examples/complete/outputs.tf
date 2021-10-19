output "azurerm_lb_id" {
  description = "The Load Balancer ID."
  value       = module.Az-PrivateLinkForNonAzureResources-Demo.lb_id
}

output "azurerm_linux_virtual_machine_scale_set_id" {
  description = "The Virtual Machine Scale Set ID."
  value       = module.Az-PrivateLinkForNonAzureResources-Demo.linux_virtual_machine_scale_set_id
}

output "azurerm_private_link_service_id" {
  description = "The Private Link ID."
  value       = module.Az-PrivateLinkForNonAzureResources-Demo.private_link_service_id
}
