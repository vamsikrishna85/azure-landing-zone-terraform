org_prefix         = "contoso"
alert_email        = "platform-oncall@example.com"
enable_vpn_gateway = false

spokes = {
  app-prod = {
    address_space = "10.10.0.0/16"
    subnets = {
      web  = "10.10.1.0/24"
      app  = "10.10.2.0/24"
      data = "10.10.3.0/24"
    }
  }
  app-nonprod = {
    address_space = "10.20.0.0/16"
    subnets = {
      web = "10.20.1.0/24"
      app = "10.20.2.0/24"
    }
  }
}

tags = {
  environment = "platform"
  owner       = "cloud-platform"
  cost_center = "it-infra"
}
