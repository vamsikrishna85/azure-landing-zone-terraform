terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.110" }
  }
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstatelz"
    container_name       = "tfstate"
    key                  = "landing-zone.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.connectivity_subscription_id
  use_oidc        = true
}

locals {
  tags = merge(var.tags, { managed_by = "terraform", workload = "landing-zone" })
}

resource "azurerm_resource_group" "connectivity" {
  name     = "rg-connectivity-${var.location_short}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "management" {
  name     = "rg-management-${var.location_short}"
  location = var.location
  tags     = local.tags
}

module "monitoring" {
  source              = "./modules/monitoring"
  resource_group_name = azurerm_resource_group.management.name
  location            = var.location
  alert_email         = var.alert_email
  tags                = local.tags
}

module "hub" {
  source                     = "./modules/hub-network"
  resource_group_name        = azurerm_resource_group.connectivity.name
  location                   = var.location
  address_space              = var.hub_address_space
  enable_vpn_gateway         = var.enable_vpn_gateway
  log_analytics_workspace_id = module.monitoring.workspace_id
  tags                       = local.tags
}

module "spokes" {
  source   = "./modules/spoke-network"
  for_each = var.spokes

  name                = each.key
  location            = var.location
  address_space       = each.value.address_space
  subnets             = each.value.subnets
  hub_vnet_id         = module.hub.vnet_id
  hub_vnet_name       = module.hub.vnet_name
  hub_resource_group  = azurerm_resource_group.connectivity.name
  firewall_private_ip = module.hub.firewall_private_ip
  use_remote_gateways = var.enable_vpn_gateway
  tags                = local.tags
}

module "governance" {
  source            = "./modules/governance"
  root_name         = var.org_prefix
  allowed_locations = var.allowed_locations
  required_tags     = var.required_tags
}
