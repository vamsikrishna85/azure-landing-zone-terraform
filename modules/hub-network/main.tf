variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "address_space" { type = string }
variable "enable_vpn_gateway" { type = bool }
variable "log_analytics_workspace_id" { type = string }
variable "tags" { type = map(string) }

locals {
  subnets = {
    AzureFirewallSubnet = cidrsubnet(var.address_space, 10, 0) # /26
    AzureBastionSubnet  = cidrsubnet(var.address_space, 10, 1) # /26
    GatewaySubnet       = cidrsubnet(var.address_space, 11, 4) # /27
  }
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${var.location}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each             = local.subnets
  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [each.value]
}

resource "azurerm_public_ip" "fw" {
  name                = "pip-fw-hub"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_firewall_policy" "hub" {
  name                     = "afwp-hub"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  sku                      = "Standard"
  threat_intelligence_mode = "Deny"
  dns { proxy_enabled = true }
  tags = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "baseline" {
  name               = "baseline"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 100

  application_rule_collection {
    name     = "allow-platform-egress"
    priority = 100
    action   = "Allow"
    rule {
      name                  = "azure-platform"
      source_addresses      = ["10.0.0.0/8"]
      destination_fqdn_tags = ["AzureKubernetesService", "WindowsUpdate", "AzureBackup"]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

resource "azurerm_firewall" "hub" {
  name                = "afw-hub"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.hub.id
  zones               = ["1", "2", "3"]
  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.this["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.fw.id
  }
  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "fw" {
  name                           = "diag-afw"
  target_resource_id             = azurerm_firewall.hub.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"
  enabled_log { category_group = "allLogs" }
  metric { category = "AllMetrics" }
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-hub"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "hub" {
  name                = "bas-hub"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.this["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
  tags = var.tags
}

resource "azurerm_public_ip" "vpn" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "pip-vpngw-hub"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "vpn" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "vgw-hub"
  resource_group_name = var.resource_group_name
  location            = var.location
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw2AZ"
  generation          = "Generation2"
  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.this["GatewaySubnet"].id
    public_ip_address_id = azurerm_public_ip.vpn[0].id
  }
  tags = var.tags
}

output "vnet_id" { value = azurerm_virtual_network.hub.id }
output "vnet_name" { value = azurerm_virtual_network.hub.name }
output "firewall_private_ip" { value = azurerm_firewall.hub.ip_configuration[0].private_ip_address }
