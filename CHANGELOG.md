## 0.3.0 (July 7, 2024)

ENHANCEMENTS:

- Allow custom names for the Private Link, Virtual Machine Scale set and Load Balancer
- Use a cheaper Virtual Machine sku with network accelerated
- Use the latest Ubuntu image
- Allow load balancer probes customization
- Ignore the VMSS identity parameter that can be managed outside terraform

## 0.2.0 (November 14, 2022)

FEATURES:

- Upgrade to Terraform 1.3.4 and above.
- Upgrade to AzureRm provider 3.31.0 and above.

ENHANCEMENTS:

- Implement a CI CD pipeline.
- Delete the deprecated version constraint in the azurerm provider.
- Code formatting with IntelliJ and `terraform fmt -recursive`.
- Add a change log file.
- Share the code example used during the Demo used during the [[HUG] Meetup Paris #17 - Novembre 2022](https://www.meetup.com/fr-FR/Hashicorp-User-Group-Paris/events/289541806/?utm_medium=email&utm_source=braze_canvas&utm_campaign=mmrk_alleng_event_announcement_prod_v7_fr&utm_term=promo&utm_content=lp_meetup).

BUG FIXES:

- Replace the deprecated block `scale_in_policy` by `scale_in` on the resource `azurerm_linux_virtual_machine_scale_set`.
- Delete the deprecated option `resource_group_name`on the resources `azurerm_lb_backend_address_pool`, `azurerm_lb_probe` and `azurerm_lb_rule`.
