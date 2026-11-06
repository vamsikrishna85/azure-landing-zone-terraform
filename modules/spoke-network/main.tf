variable "name" { type = string }
variable "location" { type = string }
variable "address_space" { type = string }
variable "subnets" { type = map(string) }
variable "hub_vnet_id" { type = string }
variable "hub_vnet_name" { type = string }
variable "hub_resource_group" { type = string }
variable "firewall_private_ip" { type = string }
variable "use_remote_gateways" { type = bool }
variable "tags" { type = map(string) }

resource "azurerm_resource_group" "spoke" {
  name     = "rg-spoke-${var.name}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-spoke-${var.name}"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_route_table" "egress" {
  name                          = "rt-${var.name}-to-fw"
  resource_group_name           = azurerm_resource_group.spoke.name
  location                      = var.location
  disable_bgp_route_propagation = true
  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall_private_ip
  }
  tags = var.tags
}

resource "azurerm_subnet" "this" {
  for_each             = var.subnets
  name                 = "snet-${each.key}"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [each.value]
}

resource "azurerm_network_security_group" "this" {
  for_each            = var.subnets
  name                = "nsg-${var.name}-${each.key}"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location

  security_rule {
    name                       = "allow-bastion-mgmt"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_ranges    = ["22", "3389"]
  }
  security_rule {
    name                       = "deny-internet-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "*"
  }
  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = var.subnets
  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each       = var.subnets
  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.egress.id
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-${var.name}-to-hub"
  resource_group_name       = azurerm_resource_group.spoke.name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = var.hub_vnet_id
  allow_forwarded_traffic   = true
  use_remote_gateways       = var.use_remote_gateways
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-${var.name}"
  resource_group_name       = var.hub_resource_group
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = var.use_remote_gateways
}

output "vnet_id" { value = azurerm_virtual_network.spoke.id }
output "subnet_ids" { value = { for k, s in azurerm_subnet.this : k => s.id } }
