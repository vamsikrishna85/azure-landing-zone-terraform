variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "alert_email" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-platform-${var.location}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = var.tags
}

resource "azurerm_monitor_action_group" "oncall" {
  name                = "ag-platform-oncall"
  resource_group_name = var.resource_group_name
  short_name          = "plat-oncall"
  email_receiver {
    name                    = "oncall"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
  tags = var.tags
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "vm_cpu" {
  name                 = "alert-vm-high-cpu"
  resource_group_name  = var.resource_group_name
  location             = var.location
  scopes               = [azurerm_log_analytics_workspace.this.id]
  severity             = 2
  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"
  description          = "Average CPU above 85% for 15 minutes"
  criteria {
    query = <<-KQL
      Perf
      | where ObjectName == "Processor" and CounterName == "% Processor Time"
      | summarize AvgCpu = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
      | where AvgCpu > 85
    KQL
    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0
  }
  action { action_groups = [azurerm_monitor_action_group.oncall.id] }
  tags = var.tags
}

data "azurerm_subscription" "current" {}

resource "azurerm_monitor_activity_log_alert" "service_health" {
  name                = "alert-service-health"
  resource_group_name = var.resource_group_name
  location            = "global"
  scopes              = [data.azurerm_subscription.current.id]
  description         = "Azure Service Health incidents affecting this subscription"
  criteria {
    category = "ServiceHealth"
    service_health {
      events    = ["Incident", "Maintenance"]
      locations = [var.location]
    }
  }
  action { action_group_id = azurerm_monitor_action_group.oncall.id }
  tags = var.tags
}

output "workspace_id" { value = azurerm_log_analytics_workspace.this.id }
output "action_group_id" { value = azurerm_monitor_action_group.oncall.id }
