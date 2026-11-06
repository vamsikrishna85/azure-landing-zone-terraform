output "hub_vnet_id" { value = module.hub.vnet_id }
output "firewall_private_ip" { value = module.hub.firewall_private_ip }
output "spoke_vnet_ids" { value = { for k, s in module.spokes : k => s.vnet_id } }
output "log_analytics_workspace_id" { value = module.monitoring.workspace_id }
