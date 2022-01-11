Content
-----
Use cases described in the following article : [Access to any non Azure resources with an Azure Private Link (Terraform module)](https://medium.com/microsoftazure/access-to-any-non-azure-resources-with-an-azure-private-link-terraform-module-b6129992dad9).

This module will create the following objects : 

- [Azure Private Link Service](https://docs.microsoft.com/en-us/azure/private-link/private-link-service-overview?WT.mc_id=AZ-MVP-5003548)
- [Azure Standard Load Balancer](https://docs.microsoft.com/en-us/azure/private-link/create-private-link-service-portal?WT.mc_id=AZ-MVP-5003548#create-an-internal-load-balancer)
- [Azure Virtual Machine Scale Set with forwarding rules](https://docs.microsoft.com/en-us/azure/data-factory/tutorial-managed-virtual-network-on-premise-sql-server?WT.mc_id=AZ-MVP-5003548#creating-forwarding-rule-to-endpoint)


High Level View
-----
![alt text](https://github.com/JamesDLD/terraform-azurerm-Az-PrivateLinkForNonAzureResources/blob/main/image/hlv.png?raw=true)


Requirement
-----
Terraform v1.1.3 and above. 
AzureRm provider version v2.81.0 and above.


Examples
-----
| Name | Description |
|------|-------------|
| [complete](https://github.com/JamesDLD/terraform-azurerm-Az-PrivateLinkForNonAzureResources/tree/main/examples/complete) | Create a private link to reach sftp and sql servers. |

