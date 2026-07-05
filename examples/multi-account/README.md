# Multi-Account IPAM Example

Cross-account, multi-region IPAM with AWS RAM using four Terraform roots: org bootstrap (management account), IPAM in a dedicated network account, and two workload stacks.

Run all commands from this directory (`examples/multi-account/`). Use `terraform -chdir=<stack>` — no `cd`.

Architecture rationale and walkthrough: [`.kiro/specs/multi-account-example/WALKTHROUGH.md`](../../.kiro/specs/multi-account-example/WALKTHROUGH.md).

## Architecture

| Stack | Account role | Region | AWS profile |
| --- | --- | --- | --- |
| [`org-bootstrap/`](org-bootstrap/) | Management | — | `ipam-org` |
| [`ipam/`](ipam/) | Network | ap-southeast-6 (home) | `ipam-network` |
| [`workload-a/`](workload-a/) | Dev workloads | ap-southeast-6 (NZ) | `ipam-workload-a` |
| [`workload-b/`](workload-b/) | Sandbox workloads | ap-southeast-2 (Sydney) | `ipam-workload-b` |

```text
Management (ipam-org)
  └── delegates IPAM admin → Network (ipam-network, home ap-southeast-6)
        ├── IPAM + org (10.0.0.0/8, no locale — global container)
        │     ├── org/nz (10.64.0.0/12, ap-southeast-6)
        │     │     └── org/nz/dev (10.64.0.0/16) ──RAM──► dev ──► VPC /20 + EC2 10.64.0.5
        │     └── org/au (10.128.0.0/12, ap-southeast-2)
        │           └── org/au/sandbox (10.128.0.0/16) ──RAM──► sandbox ──► VPC /20 + EC2 10.128.0.5
```

The org management account **cannot** host IPAM. IPAM runs in the delegated **network** member account. See [FINDINGS.md](FINDINGS.md).

## Directory layout

```text
examples/multi-account/
├── README.md
├── FINDINGS.md
├── .gitignore
├── org-bootstrap/
├── ipam/
├── modules/
│   └── ipam-vpc/          # IPAM pool-backed VPC (shared by workloads)
├── workload-a/
└── workload-b/
```

## Prerequisites

- AWS Organizations: management account + network account + two workload accounts
- IAM: org delegation permissions on management; IPAM/RAM/VPC on member accounts
- RAM resource share auto-accept for organization accounts
- AWS SSO profiles in `~/.aws/config` (see [Credentials](#credentials))

## Credentials

Four profiles — one per account:

| Profile | Account role | Stacks |
| --- | --- | --- |
| `ipam-org` | Management | `org-bootstrap/` |
| `ipam-network` | Network | `ipam/` |
| `ipam-workload-a` | Dev workloads | `workload-a/` |
| `ipam-workload-b` | Sandbox workloads | `workload-b/` |

Before each step, set the profile and confirm the account:

```bash
export AWS_PROFILE=ipam-org
aws sts get-caller-identity
```

## Apply order

Copy `terraform.tfvars.example` to `terraform.tfvars` in each stack once (edit values as needed).

### 1. Org bootstrap (management account)

Delegates the network account as IPAM admin and enables RAM sharing with AWS Organizations (management account only).

```bash
export AWS_PROFILE=ipam-org
aws sts get-caller-identity

cp org-bootstrap/terraform.tfvars.example org-bootstrap/terraform.tfvars
terraform -chdir=org-bootstrap init
terraform -chdir=org-bootstrap apply
```

### 2. IPAM (network account)

IPAM home region is **ap-southeast-6** (NZ). Operating regions include ap-southeast-2 via pool locales.

```bash
export AWS_PROFILE=ipam-network
aws sts get-caller-identity

cp ipam/terraform.tfvars.example ipam/terraform.tfvars
terraform -chdir=ipam init
terraform -chdir=ipam apply
```

Note outputs: `nz_dev_pool_id`, `au_sandbox_pool_id`, `operating_regions`. `ram_share_pool_keys` should list `org/nz/dev` and `org/au/sandbox`.

`ram_share_principals` on leaf pools RAM-shares each pool to a workload account (permission to use the pool). **IPAM usage visibility** in the network account requires a formal pool allocation when the workload creates its VPC — see [WALKTHROUGH.md](../../.kiro/specs/multi-account-example/WALKTHROUGH.md#workload-onboarding-and-ipam-visibility).

```bash
terraform -chdir=ipam output operating_regions
terraform -chdir=ipam output nz_dev_pool_id
terraform -chdir=ipam output au_sandbox_pool_id
```

### 3. Workload stacks

Workload A and B can run in parallel after step 2.

**Workload A (dev, ap-southeast-6):**

```bash
export AWS_PROFILE=ipam-workload-a
aws sts get-caller-identity

cp workload-a/terraform.tfvars.example workload-a/terraform.tfvars
# Set pool_id to nz_dev_pool_id from ipam
terraform -chdir=workload-a init
terraform -chdir=workload-a apply
```

**Workload B (sandbox, ap-southeast-2):**

```bash
export AWS_PROFILE=ipam-workload-b
aws sts get-caller-identity

cp workload-b/terraform.tfvars.example workload-b/terraform.tfvars
# Set pool_id to au_sandbox_pool_id from ipam
terraform -chdir=workload-b init
terraform -chdir=workload-b apply
```

### Post-apply

```bash
terraform -chdir=workload-a output vpc_cidr
terraform -chdir=workload-a output demo_private_ip
terraform -chdir=workload-b output vpc_cidr
terraform -chdir=workload-b output demo_private_ip
```

## Destroy order

```bash
export AWS_PROFILE=ipam-workload-a
terraform -chdir=workload-a destroy

export AWS_PROFILE=ipam-workload-b
terraform -chdir=workload-b destroy

export AWS_PROFILE=ipam-network
terraform -chdir=ipam destroy

# org-bootstrap delegation is typically left in place
```

## Stack contract

| ipam output | Workload input | Stack |
| --- | --- | --- |
| `nz_dev_pool_id` | `pool_id` | `workload-a/` (ap-southeast-6) |
| `au_sandbox_pool_id` | `pool_id` | `workload-b/` (ap-southeast-2) |

Pool IDs are copied via `terraform.tfvars` (no remote state). This is the stack contract handoff from ipam to workloads — not IPAM allocation itself.

## Notes

- Regional pool **locale** must match the workload VPC region
- IPAM console shows **Private** and **Public** scopes; all pools in this example are under **Private** (Public is auto-created but unused — see [WALKTHROUGH.md](../../.kiro/specs/multi-account-example/WALKTHROUGH.md))
- Both child pools are RAM-shared from the network account (`ram_share_principals` = permission to use pool; see [WALKTHROUGH — onboarding](../../.kiro/specs/multi-account-example/WALKTHROUGH.md#workload-onboarding-and-ipam-visibility))
- Workload VPCs are created with **`ipv4_ipam_pool_id`** via `modules/ipam-vpc/` — IPAM shows them as **Managed** and lists them on the pool **Allocations** tab
- Subnet CIDRs are derived from the pool-allocated VPC CIDR at apply time (`cidrsubnet` on `aws_vpc.cidr_block`)
- Workload VPCs disable NAT gateway for demo cost; each includes a `t3.nano` with `.5` reserved in the first public subnet — host IP visible centrally via IPAM **Monitoring → Resources → ENIs** (see [WALKTHROUGH](../../.kiro/specs/multi-account-example/WALKTHROUGH.md#ipam-vs-host-ip))
- **Monitoring dashboard is org-wide** — it discovers all member-account VPCs/subnets, not only pools from `ipam/main.tf`; see [Pools vs monitoring](../../.kiro/specs/multi-account-example/WALKTHROUGH.md#pools-vs-monitoring-what-ipammaintf-controls)
- **Recreating** an existing workload stack replaces the old VPC (destroy + create). Expect brief downtime on the demo EC2
- Destroy any IPAM created in the management or dev accounts from earlier layouts before applying `ipam/` in the network account
