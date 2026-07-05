# Multi-Account IPAM — Findings

Notes from implementing and applying the multi-account example. Add new items here as we learn more.

## IPAM must run in a member account (not management)

The AWS Organizations **management account cannot be the IPAM admin account**. Delegation and IPAM creation belong in a **member account**.

- API error when using management account: `IpamOrganizationDelegatedAdminCannotBeRootAccount`
- After delegation, the management account’s role is done; the **delegated member account** must create and operate IPAM.

- [Integrate IPAM with accounts in an AWS Organization](https://docs.aws.amazon.com/vpc/latest/ipam/enable-integ-ipam.html)
- [EnableIpamOrganizationAdminAccount API](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_EnableIpamOrganizationAdminAccount.html)
- [aws_vpc_ipam_organization_admin_account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_ipam_organization_admin_account) (Terraform)

## RAM pool sharing requires org-integrated IPAM

IPAM pools can only be shared via RAM when IPAM is integrated with AWS Organizations (delegated admin flow above). Single-account IPAM cannot use this sharing model.

You must also enable **resource sharing with AWS Organizations** in RAM before associating pools or principals.

- [Share an IPAM pool using AWS RAM](https://docs.aws.amazon.com/vpc/latest/ipam/share-pool-ipam.html)
- [Enable resource sharing within AWS Organizations (RAM)](https://docs.aws.amazon.com/ram/latest/userguide/getting-started-sharing.html)

## Terraform: RAM org sharing bootstrap

`aws_ram_sharing_with_organization` **must run in the org management account**. Member accounts (including the delegated IPAM admin) get `AccessDeniedException from AWSOrganizations`.

In this example, `org-bootstrap/` (management account) enables RAM org sharing. The `ipam/` stack in the network account creates pools and RAM shares only — it does not call `enable_ram_sharing_with_organization`.

The root module still supports `enable_ram_sharing_with_organization` for single-account or management-account applies; default is `false`.

- [aws_ram_sharing_with_organization](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_sharing_with_organization)

## RAM principals for member accounts

For organization members, RAM accepts a **12-digit AWS account ID** as a principal (no need for a constructed Organizations ARN).

Invalid pattern (do not use): `arn:aws:organizations::<mgmt>:account/<org_id>/<account_id>`

- [CreateResourceShare (RAM API)](https://docs.aws.amazon.com/ram/latest/APIReference/API_CreateResourceShare.html)

## Error we hit when architecture was wrong

When IPAM lived in the management account, apply failed on RAM associations with:

```text
OperationNotPermittedException: The resource you are attempting to share can only be shared
within your AWS Organization.
```

Enabling RAM org sharing in Terraform did not fix this—the root cause was **IPAM in the management account**, not missing `enable-sharing-with-aws-organization` alone.

- [RAM: errors sharing outside organization](https://docs.aws.amazon.com/ram/latest/userguide/tshoot-sharing-outside-org.html)

## Intended apply order (correct pattern)

1. **Org management account** (`ipam-org`) — `org-bootstrap/` delegates IPAM admin and enables RAM org sharing
2. **Network account** (`ipam-network`) — `ipam/` creates IPAM, pools, RAM shares to both workload accounts
3. **Workload accounts** — `workload-a/` on dev (`ipam-workload-a`), `workload-b/` on sandbox (`ipam-workload-b`)

Example account mapping:

| Account role | Profile | Stacks |
| --- | --- | --- |
| Management | `ipam-org` | `org-bootstrap/` |
| Network | `ipam-network` | `ipam/` |
| Dev workloads | `ipam-workload-a` | `workload-a/` (ap-southeast-6) |
| Sandbox workloads | `ipam-workload-b` | `workload-b/` (ap-southeast-2) |

The org management account cannot host IPAM. A dedicated network member account is the delegated IPAM admin.

## Multi-region layout

IPAM home region is **ap-southeast-6** (NZ). Pool hierarchy:

```text
org (10.0.0.0/8, no locale)
├── org/nz (10.64.0.0/12, ap-southeast-6) → org/nz/dev (10.64.0.0/16) → dev VPC
└── org/au (10.128.0.0/12, ap-southeast-2) → org/au/sandbox (10.128.0.0/16) → sandbox VPC
```

The root `org` pool must **not** set a locale. If it does, AWS rejects regional child pools with a different locale (`InvalidParameterCombination: sourcePoolId ... has a locale ... with a different region from input locale`).

Pool **locale** on leaf pools must match the region where VPCs are created. Operating regions are derived from pool locales plus the IPAM home region.

## Private vs public IPAM scope

AWS creates **two default scopes** when an IPAM is provisioned: **Private** (RFC1918 VPC space) and **Public** (BYOIP / public IPv4). You cannot opt out of either.

This example uses the **Private** scope only (`scope_type = "private"` module default). All `10.x` pools appear under Private in the console. **Public is empty by design** — no extra cost, no action required. Select **Private** in the scope dropdown to view pools.

- [Create an IPAM](https://docs.aws.amazon.com/vpc/latest/ipam/create-ipam.html) — home vs operating regions
- [Work with IPAM pools](https://docs.aws.amazon.com/vpc/latest/ipam/work-with-ipam.html) — locale

Design rationale: [`.kiro/specs/multi-account-example/WALKTHROUGH.md`](../../.kiro/specs/multi-account-example/WALKTHROUGH.md)

## RAM share vs IPAM allocation visibility

`ram_share_principals` in `ipam/main.tf` (wired to RAM in `modules/pool/main.tf`) grants each workload account **permission to use** the shared pool. It does **not** automatically publish VPC usage to the network account IPAM dashboard.

For usage to appear under **IPAM → pool → Allocations** in the network account, the workload must create a formal **IPAM allocation** (typically `aws_vpc` with `ipv4_ipam_pool_id` + `ipv4_netmask_length`).

Host-level IPs (e.g. `10.64.0.5` on a demo ENI) **are** visible centrally when org IPAM monitoring is enabled: **IPAM → Monitoring → Resources** → subnet → **ENIs** tab (network account). That is **resource discovery**, not the same as **Pools → Allocations** (formal pool→VPC CIDR blocks).

Workload stacks create VPCs with **`ipv4_ipam_pool_id`** via `modules/ipam-vpc/`, so the **Allocations** tab shows the `/20` VPC CIDR with owner = workload account.

See [IPAM vs host IP](../../.kiro/specs/multi-account-example/WALKTHROUGH.md#ipam-vs-host-ip).

- [Allocate CIDRs from an IPAM pool](https://docs.aws.amazon.com/vpc/latest/ipam/allocate-cidrs-ipam.html)

## Stack vs profile naming

The IPAM Terraform stack is **`ipam/`**. Step 2 uses profile **`ipam-network`** (network account). Workload stacks use **`ipam-workload-a`** and **`ipam-workload-b`**.

## SSO credentials

Run `aws sso login --sso-session <session>` before applies. Always verify `aws sts get-caller-identity` succeeds **before** `terraform apply`. A `403 ForbiddenException: No access` from SSO means the user lacks an IAM Identity Center assignment for that account/permission set — Terraform will fail with `No valid credential sources found`.

Do not continue to Terraform when `get-caller-identity` fails. For the network account, ensure `sso_role_name=AdministratorAccess` in the `ipam-network` profile — `AWSAdministratorAccess` returns `403 ForbiddenException: No access` in this org even though the user is assigned.

## Module inputs added for RAM bootstrap

| Input | Purpose |
| --- | --- |
| `enable_ram_sharing_with_organization` | Enable RAM trusted access before shares |
| `ram_sharing_enable_wait_duration` | Wait after enable (org onboarding lag) |
