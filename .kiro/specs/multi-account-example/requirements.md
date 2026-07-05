# Requirements Document

## Introduction

Multi-account, multi-region example (`examples/multi-account/`) demonstrating AWS Organizations IPAM with RAM sharing across four Terraform roots: org bootstrap (management), IPAM (network), and two workload stacks (dev in ap-southeast-6, sandbox in ap-southeast-2).

Architecture rationale: [WALKTHROUGH.md](WALKTHROUGH.md).

## Glossary

- **Org_Bootstrap_Stack**: `examples/multi-account/org-bootstrap/` — management account; delegates IPAM admin and enables RAM org sharing.
- **IPAM_Stack**: `examples/multi-account/ipam/` — network account; creates IPAM, regional pool hierarchy, RAM shares.
- **Workload_Stack**: `workload-a/` or `workload-b/` — member account VPC + demo EC2 from RAM-shared pool.
- **IPAM_Module**: Root module (`source = "../../.."`) used by IPAM_Stack.
- **IPAM_VPC_Module**: `examples/multi-account/modules/ipam-vpc/` — pool-backed VPC + subnets (shared by workload stacks).
- **Pool_Hierarchy**: Three-level regional structure: `org` → `nz`/`au` → `dev`/`sandbox`.
- **Stack_Contract**: IPAM outputs → workload `pool_id` via `terraform.tfvars` (no remote state).

## Requirements

### Requirement 1: Example Directory Structure

1. THE Example_Directory SHALL contain four Terraform roots: `org-bootstrap/`, `ipam/`, `workload-a/`, `workload-b/`.
2. THE Example_Directory SHALL contain shared module `modules/ipam-vpc/`.
3. THE Example_Directory SHALL contain `README.md`, `FINDINGS.md`, and link to `WALKTHROUGH.md` in this spec folder.
4. Each Terraform root SHALL contain `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, and `terraform.tfvars.example`.
5. Each Terraform root SHALL be independent with its own `provider "aws"` block.
6. Committed files SHALL NOT contain real AWS account IDs, org IDs, or live resource IDs — use placeholders in `*.tfvars.example` only; real values in gitignored `terraform.tfvars`.

### Requirement 2: Org Bootstrap Stack

1. THE Org_Bootstrap_Stack SHALL create `aws_vpc_ipam_organization_admin_account` delegating a network member account.
2. THE Org_Bootstrap_Stack SHALL create `aws_ram_sharing_with_organization` and optional `time_sleep` wait (management account only).
3. THE Org_Bootstrap_Stack SHALL declare `ipam_admin_account_id` and `ram_sharing_enable_wait_duration`.

### Requirement 3: IPAM Stack — Regional Pool Hierarchy

1. THE IPAM_Stack SHALL invoke IPAM_Module with `source = "../../.."`.
2. THE IPAM_Stack provider region (`primary_region`) SHALL default to `ap-southeast-6` (IPAM home).
3. THE IPAM_Stack SHALL define `org` pool with CIDR `10.0.0.0/8` and **no locale** (global container for regional sub-pools).
4. THE IPAM_Stack SHALL define `org/nz` with CIDR `10.64.0.0/12`, locale `primary_region`.
5. THE IPAM_Stack SHALL define `org/nz/dev` with CIDR `10.64.0.0/16`, locale `primary_region`, `allocation_default_netmask_length = 20`, RAM share to workload account A.
6. THE IPAM_Stack SHALL define `org/au` with CIDR `10.128.0.0/12`, locale `secondary_region` (`ap-southeast-2`).
7. THE IPAM_Stack SHALL define `org/au/sandbox` with CIDR `10.128.0.0/16`, locale `secondary_region`, `allocation_default_netmask_length = 20`, RAM share to workload account B.
8. THE IPAM_Stack SHALL NOT enable `enable_ram_sharing_with_organization` on IPAM_Module (handled in org-bootstrap).
9. WALKTHROUGH.md SHALL document that `ram_share_principals` grants pool **access** via RAM, that workloads create VPCs with **`ipv4_ipam_pool_id`** for formal **Allocations**, and that **Monitoring** is org-wide discovery (not limited to pool config).

### Requirement 4: IPAM Stack Outputs

1. `ipam_id`, `operating_regions`, `nz_dev_pool_id`, `au_sandbox_pool_id`, `ram_share_pool_keys`.
2. `ram_share_pool_keys` SHALL include `org/nz/dev` and `org/au/sandbox`.

### Requirement 5: Workload Stack VPC and Demo EC2

1. Workload stacks SHALL accept `pool_id`, `region`, and optional `name` / `tags`.
2. Workload-a default region: `ap-southeast-6`. Workload-b default region: `ap-southeast-2`.
3. Workload stacks SHALL use `modules/ipam-vpc/` with `ipv4_ipam_pool_id` and `ipv4_netmask_length = 20` (pool-backed VPC — **Managed** in IPAM).
4. Workload stacks SHALL NOT use NAT gateway (no NAT in `ipam-vpc` module).
5. Workload stacks SHALL reserve `cidrhost(first_public_subnet, 5)/32` with `aws_ec2_subnet_cidr_reservation` (`explicit`), then launch one `t3.nano` with matching `private_ip`.
6. Workload stacks SHALL output `vpc_id`, `vpc_cidr`, `demo_private_ip`, `demo_instance_id`.
7. Workload stacks SHALL NOT create IPAM resources or invoke IPAM_Module.

### Requirement 6: Stack Contract

1. No `terraform_remote_state` in any stack.
2. `nz_dev_pool_id` → `workload-a/terraform.tfvars` `pool_id`.
3. `au_sandbox_pool_id` → `workload-b/terraform.tfvars` `pool_id`.

### Requirement 7: Documentation

1. README SHALL document four-account, multi-region architecture, apply/destroy order, profiles.
2. WALKTHROUGH.md SHALL document design decisions, console reference (Planning vs Monitoring), RAM dependency, and workload onboarding (RAM share vs IPAM allocation vs org discovery).
3. FINDINGS.md SHALL document empirical errors from applies (not design rationale).
4. Committed documentation SHALL NOT include real AWS account IDs or live pool/IPAM resource IDs from applies.

### Requirement 8: Non-Goals

1. No Transit Gateway, VPC peering, VPN, Direct Connect.
2. No live multi-account tests in the example directory.
3. Delegated IPAM admin in a network member account is **required** (not a non-goal).
