output "lb_id" {
  description = "The Load Balancer ID."
  value       = azurerm_lb.lbi.id
}

output "linux_virtual_machine_scale_set_id" {
  description = "The Virtual Machine Scale Set ID."
  value       = azurerm_linux_virtual_machine_scale_set.vmss_linux.id
}

output "private_link_service_id" {
  description = "The Private Link ID."
  value       = azurerm_private_link_service.pls.id
}
