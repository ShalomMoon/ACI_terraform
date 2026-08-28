# ACI Terraform deployment

This repository converts the `aci_ansible` MATLAB deployment into a compact,
declarative Terraform configuration for a fresh Cisco ACI fabric.

## What it deploys

- VLAN pool 1401-1421, physical domain, and AAEP
- CDP, LLDP, MCP, link-level, and LACP interface policies
- Access and vPC interface policy groups
- Leaf 101/102 interface profiles, selectors, port blocks, switch profiles,
  node selectors, and a vPC protection group
- Two tenants, four application profiles, two VRFs, three bridge domains, and
  six subnets
- Five EPGs with physical-domain associations
- Nine filters, thirteen filter entries, five contracts, and five subjects
- Sixty static EPG path bindings generated from five compact binding groups

The source data is in `data/aci.yaml`. Terraform uses stable `for_each` keys so
objects can be added or removed without renumbering unrelated resources.

## Prerequisites

- Terraform 1.8 or later
- Network access from the Terraform server to an APIC
- A dedicated APIC automation account with suitable permissions
- A fresh ACI fabric with leaf nodes 101 and 102 registered
- APIC certificates trusted by the Terraform server, or temporary use of
  `aci_insecure=true`

Review all names, node IDs, interfaces, VLANs, and IP addressing before apply.
The data intentionally preserves the original contract-to-EPG bindings as
providers only; add consumer bindings to `data/aci.yaml` when the intended
application traffic policy is known.

## Clone and initialize

```bash
git clone https://github.com/ShalomMoon/ACI_terraform.git
cd ACI_terraform
terraform init
```

## Supply credentials safely

Do not store an APIC password in Git or `terraform.tfvars`.

```bash
export TF_VAR_aci_url='https://apic.example.com'
export TF_VAR_aci_username='terraform'
export TF_VAR_aci_password='replace-me'
export TF_VAR_aci_insecure='true'
```

Use `TF_VAR_aci_insecure=false` after installing a trusted APIC certificate.

## Validate and deploy

Take an APIC configuration export before applying changes. Snapshot/export
operations are deliberately kept outside Terraform because they are operational
actions, not persistent desired state.

```bash
terraform fmt -check -recursive
terraform validate
terraform plan -out=aci.tfplan
terraform apply aci.tfplan
terraform plan
```

The final plan should report no changes.

## Customize the deployment

Edit `data/aci.yaml`; avoid editing resource blocks for normal ACI additions.

Common changes include:

- `fabric.vpc_protection_groups`: node IDs and protection-group ID
- `fabric.interface_profiles`: interface selectors and policy groups
- `fabric.leaf_profiles`: leaf IDs and interface-profile relationships
- `tenants.*.bridge_domains`: VRFs, subnets, and forwarding behavior
- `tenants.*.application_profiles.*.epgs`: EPGs and static bindings
- `tenants.*.contracts`: provider and consumer EPG bindings

To add a contract consumer, append another binding:

```yaml
epg_bindings:
  - { application_profile: App-1_AP, epg: App_EPG, type: provider }
  - { application_profile: App-1_AP, epg: Web_EPG, type: consumer }
```

## State handling

Terraform state may contain sensitive infrastructure information. State files
are excluded by `.gitignore`. For team or production use, configure a secured
remote backend with encryption, locking, access control, and versioning before
the first apply.

This configuration targets a fresh deployment. Existing APIC objects must be
imported into Terraform state before Terraform is permitted to manage them.
