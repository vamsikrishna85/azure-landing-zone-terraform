# Azure Landing Zone — Terraform

**Enterprise hub-and-spoke Azure landing zone with governance, security and observability, built entirely with Terraform.**

A reference implementation of the foundation I design before migrating workloads to Azure: a central hub for shared connectivity and security, isolated spokes per workload, guardrails enforced through Azure Policy, and monitoring that is ready on day one.

> Showcase project. It reflects patterns I've used on enterprise landing-zone and migration engagements, with every client-specific detail removed.

## Architecture

```mermaid
flowchart TB
  subgraph MG[Management groups]
    root[org-root] --> plat[platform] & lz[landing-zones] & sbx[sandbox]
  end
  subgraph HUB[Hub VNet 10.0.0.0/16]
    fw[Azure Firewall]
    vpn[VPN Gateway]
    bas[Azure Bastion]
  end
  onprem[(On-prem DC)] -- S2S VPN --- vpn
  HUB <-- peering --> S1[Spoke: app-prod 10.10.0.0/16]
  HUB <-- peering --> S2[Spoke: app-nonprod 10.20.0.0/16]
  S1 & S2 -. UDR 0.0.0.0/0 .-> fw
  LA[(Log Analytics)] --- HUB & S1 & S2
```

## Modules

| Module | Provisions |
|---|---|
| `hub-network` | Hub VNet, firewall, gateway and Bastion subnets, Azure Firewall with policy, Bastion, optional VPN gateway |
| `spoke-network` | Spoke VNet, workload subnets with NSGs, route table forcing egress through the firewall, bidirectional peering |
| `governance` | Management group hierarchy and policy assignments: allowed locations, required tags, deny public IPs on NICs, Defender for Cloud |
| `monitoring` | Log Analytics workspace, action group, alerts for sustained VM CPU and Azure Service Health incidents |

## Pipeline

`.github/workflows/terraform.yml` runs `fmt`, `validate`, `tflint` and `checkov` on every pull request, posts the plan, applies on merge behind a protected `production` environment, and runs a **nightly drift detection** job that opens an issue when live infrastructure no longer matches code.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # or use env/prod.tfvars
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

## Design decisions

- **Forced tunnelling through Azure Firewall**: spokes have no direct internet egress; all traffic is inspected and logged.
- **Policy before workloads**: guardrails are assigned at the management-group level so every new subscription inherits them.
- **No public management ports**: VM access only through Azure Bastion.
- **Remote state with locking** in a dedicated storage account, using OIDC from CI with no stored secrets.

---
Author: **Vamsikrishna Gollapudi** · Azure DevOps & SRE · [Portfolio](https://vamsikrishna85.github.io/my-profile/)
