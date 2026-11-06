variable "root_name" { type = string }
variable "allowed_locations" { type = list(string) }
variable "required_tags" { type = list(string) }

data "azurerm_client_config" "current" {}

resource "azurerm_management_group" "root" {
  name                       = "${var.root_name}-root"
  display_name               = "${upper(var.root_name)} Root"
  parent_management_group_id = "/providers/Microsoft.Management/managementGroups/${data.azurerm_client_config.current.tenant_id}"
}

resource "azurerm_management_group" "children" {
  for_each                   = toset(["platform", "landing-zones", "sandbox"])
  name                       = "${var.root_name}-${each.key}"
  display_name               = title(replace(each.key, "-", " "))
  parent_management_group_id = azurerm_management_group.root.id
}

# Built-in policy definitions (IDs are stable across tenants)
locals {
  policy = {
    allowed_locations   = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
    require_tag         = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
    deny_nic_pip        = "/providers/Microsoft.Authorization/policyDefinitions/83a86a26-fd1f-447c-b59d-e51f44264114"
    defender_initiative = "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8"
  }
}

resource "azurerm_management_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed locations"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = local.policy.allowed_locations
  parameters           = jsonencode({ listOfAllowedLocations = { value = var.allowed_locations } })
}

resource "azurerm_management_group_policy_assignment" "require_tag" {
  for_each             = toset(var.required_tags)
  name                 = substr("require-tag-${replace(each.key, "_", "-")}", 0, 24)
  display_name         = "Require tag '${each.key}' on resources"
  management_group_id  = azurerm_management_group.children["landing-zones"].id
  policy_definition_id = local.policy.require_tag
  parameters           = jsonencode({ tagName = { value = each.key } })
}

resource "azurerm_management_group_policy_assignment" "deny_public_ip" {
  name                 = "deny-nic-public-ip"
  display_name         = "Network interfaces should not have public IPs"
  management_group_id  = azurerm_management_group.children["landing-zones"].id
  policy_definition_id = local.policy.deny_nic_pip
}

resource "azurerm_management_group_policy_assignment" "security_benchmark" {
  name                 = "mcsb"
  display_name         = "Microsoft cloud security benchmark"
  management_group_id  = azurerm_management_group.root.id
  policy_definition_id = local.policy.defender_initiative
}

output "landing_zones_mg_id" { value = azurerm_management_group.children["landing-zones"].id }
