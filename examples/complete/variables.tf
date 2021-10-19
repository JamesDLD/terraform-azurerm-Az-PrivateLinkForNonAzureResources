variable "subscription_id" {
  description = "Azure subscription Id."
}

#Set variable
variable "forwarding_rules" {
  description = "Forwarding Rule to Endpoint (cf https://docs.microsoft.com/en-us/azure/data-factory/tutorial-managed-virtual-network-on-premise-sql-server?WT.mc_id=AZ-MVP-5003548&WT.mc_id=AZ-MVP-5003548#creating-forwarding-rule-to-endpoint)."
  type        = any
  default = {
    "sql-demo1" = {
      source_port         = "1433"
      destination_address = "sql1.dld23.com"
      destination_port    = "1433"
    }
    "sql-demo2" = {
      source_port         = "1434"
      destination_address = "sql2.dld23.com"
      destination_port    = "1433"
    }
    "sftp-demo1" = {
      source_port         = "221"
      destination_address = "sftp.dld23.com"
      destination_port    = "22"
    }
  }
}
