variable "connectivity_subscription_id" { type = string }

variable "org_prefix" {
  type        = string
  description = "Short organisation prefix used for management group names."
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "location_short" {
  type    = string
  default = "cin"
}

variable "allowed_locations" {
  type    = list(string)
  default = ["centralindia", "southindia"]
}

variable "required_tags" {
  type    = list(string)
  default = ["environment", "owner", "cost_center"]
}

variable "hub_address_space" {
  type    = string
  default = "10.0.0.0/16"
}

variable "enable_vpn_gateway" {
  type    = bool
  default = false
}

variable "spokes" {
  description = "Spoke VNets keyed by name."
  type = map(object({
    address_space = string
    subnets       = map(string)
  }))
}

variable "alert_email" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}
