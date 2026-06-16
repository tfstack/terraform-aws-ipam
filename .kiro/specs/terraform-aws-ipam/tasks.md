# Implementation Plan: terraform-aws-ipam

## Overview

Implement the `terraform-aws-ipam` Terraform module following tfstack conventions. The root module is an orchestrator only — no AWS resources directly. Two submodules (`ipam-core` and `pool`) handle resource creation. A pool flattening algorithm in locals transforms nested pool maps into a for_each-friendly flat structure. Implementation follows dependency order: submodules first, then root orchestration, then example, then docs and tests.

## Task Dependency Graph

```json
{
  "waves": [
    {
      "name": "Foundation",
      "tasks": ["1"]
    },
    {
      "name": "Submodules",
      "tasks": ["2", "3"]
    },
    {
      "name": "Submodule Validation",
      "tasks": ["4"]
    },
    {
      "name": "Root Module",
      "tasks": ["5"]
    },
    {
      "name": "Root Validation",
      "tasks": ["6"]
    },
    {
      "name": "Example",
      "tasks": ["7"]
    },
    {
      "name": "Example Validation",
      "tasks": ["8"]
    },
    {
      "name": "Tests & Documentation",
      "tasks": ["9", "10"]
    },
    {
      "name": "Final Validation",
      "tasks": ["11"]
    }
  ]
}
```

## Tasks

- [x] 1. Create repository scaffolding and version constraints
  - Create `versions.tf` with `terraform >= 1.3` and `aws >= 5.0` provider constraints
  - Create `modules/ipam-core/versions.tf` and `modules/pool/versions.tf` with matching constraints
  - Create `.gitignore` for Terraform modules (`.terraform/`, `*.tfstate`, `*.tfstate.backup`, `.terraform.lock.hcl`, `crash.log`)
  - Create `.terraform-docs.yaml` configuration
  - Create directory structure: `modules/ipam-core/`, `modules/pool/`, `examples/basic/`, `tests/`
  - _Requirements: 9.2, 9.3, 9.4_

- [x] 2. Implement modules/ipam-core submodule
  - [x] 2.1 Create `modules/ipam-core/variables.tf`
    - Define `create` (bool, default true), `operating_regions` (list(string)), `description` (string, default null), `tags` (map(string), default {})
    - _Requirements: 1.1, 1.2_
  - [x] 2.2 Create `modules/ipam-core/main.tf`
    - Create `aws_vpc_ipam.this` with count controlled by `var.create`
    - Use dynamic `operating_regions` block iterating over `var.operating_regions`
    - Set description and tags from variables
    - _Requirements: 1.1, 1.2_
  - [x] 2.3 Create `modules/ipam-core/outputs.tf`
    - Output `id`, `arn`, `private_default_scope_id`, `public_default_scope_id`
    - Use conditional expressions to handle `create = false` (output null)
    - _Requirements: 1.3_

- [x] 3. Implement modules/pool submodule
  - [x] 3.1 Create `modules/pool/variables.tf`
    - Define all pool inputs: `create`, `address_family`, `ipam_scope_id`, `source_ipam_pool_id`, `key`, `cidr`, `locale`, `implied_locale`, `description`, allocation params, `auto_import`, `allocation_resource_tags`, `ram_share_principals`, `ram_permission_arn`, `tags`
    - _Requirements: 3.1, 3.4, 4.1_
  - [x] 3.2 Create `modules/pool/main.tf` — pool and CIDR resources
    - Create `aws_vpc_ipam_pool.this` with count via `var.create`
    - Set `address_family`, `ipam_scope_id`, `source_ipam_pool_id`, `locale`, allocation params, `auto_import`, `allocation_resource_tags`
    - Create `aws_vpc_ipam_pool_cidr.this` with for_each over `var.cidr`
    - _Requirements: 3.1, 3.2, 3.3, 3.4_
  - [x] 3.3 Create `modules/pool/main.tf` — RAM share resources
    - Create `aws_ram_resource_share.this` with count conditional on `length(var.ram_share_principals) > 0 && var.create`
    - RAM share name: `replace(var.key, "/", "-")`
    - Create `aws_ram_resource_association.this` with same count
    - Create `aws_ram_principal_association.this` with for_each over `var.ram_share_principals`
    - Set `ram_permission_arn` on resource association
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
  - [x] 3.4 Create `modules/pool/outputs.tf`
    - Output `id`, `arn`, `locale`, `cidr` (list of provisioned CIDRs)
    - Handle `create = false` with conditional null outputs
    - _Requirements: 3.5_

- [x] 4. Checkpoint — Verify submodules
  - Run `terraform validate` in `modules/ipam-core/` and `modules/pool/` to confirm syntax is correct
  - Review outputs handle `create = false` correctly (conditional null, not index-out-of-range)
  - Ask the user if questions arise before proceeding to root module

- [x] 5. Implement root module pool flattening and orchestration
  - [x] 5.1 Create `variables.tf` with root variables
    - Define `create`, `create_ipam`, `ipam_scope_id`, `scope_type`, `address_family`, `description`, `pools`, `tags`
    - `address_family` is a global default applied to all pools (not per-pool); default `"ipv4"`
    - Use the full nested pools type definition (max depth 3 via type structure); L2 and L3 `sub_pools` objects must include the same optional allocation params (`allocation_min/max/default_netmask_length`, `allocation_resource_tags`, `auto_import`) as L1
    - Add `validation` block: when `create_ipam = false`, `ipam_scope_id` must be non-null (use `precondition` in locals or a root `variable` validation)
    - Add `validation` block (or documented constraint): top-level pool keys must not contain `/` (reserved as path separator)
    - _Requirements: 2.1, 6.1, 6.2, 6.3_
  - [x] 5.2 Create `main.tf` — pool flatten logic in locals
    - Implement `l1_pools`, `l2_pools`, `l3_pools` locals that walk the nested map
    - Merge into `flat_pools` with `parent_key` and `implied_locale` for each entry
    - Key format: L1 = "key", L2 = "key/subkey", L3 = "key/subkey/subsubkey"
    - Locale coalescing: `coalesce(child.locale, parent.locale, grandparent.locale)`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_
  - [x] 5.3 Create `main.tf` — operating regions and scope resolution
    - Derive `operating_regions` using `distinct(concat([current_region], [pool locales]))`
    - Resolve `scope_id` based on `create_ipam` and `scope_type`
    - Add `data "aws_region" "current" {}`
    - _Requirements: 5.1, 5.2, 5.3, 6.1, 6.2, 6.3_
  - [x] 5.4 Create `main.tf` — module calls
    - Call `module.ipam_core` with count based on `var.create && var.create_ipam`
    - Call `module.pool` with for_each over `var.create ? local.flat_pools : {}`
    - Wire `source_ipam_pool_id` from `module.pool[each.value.parent_key].id`
    - Pass through all pool attributes from flat_pools entries
    - Add `depends_on = [module.ipam_core]` to pool module
    - _Requirements: 1.1, 1.4, 3.1, 3.2_
  - [x] 5.5 Create `outputs.tf` with root outputs
    - Output `ipam_id`, `ipam_arn`, `private_scope_id`
    - Output `pools` map with id, arn, locale, cidr per pool
    - Output `pool_ids` convenience map (path → pool ID only)
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 6. Checkpoint — Verify root module
  - Run `terraform validate` on root module
  - Manually verify `flat_pools` structure by tracing the locals with a 2-level pools example
  - Confirm `operating_regions`, `scope_id`, and `source_ipam_pool_id` wiring resolve correctly
  - Ask the user if questions arise before proceeding to example

- [x] 7. Create examples/basic
  - [x] 7.1 Create `examples/basic/versions.tf`
    - Terraform >= 1.3, AWS provider >= 5.0
    - _Requirements: 9.2_
  - [x] 7.2 Create `examples/basic/variables.tf`
    - Define `region` (default "eu-west-1"), `name` (default "ipam-basic"), `tags` (default { Example = "basic" })
    - _Requirements: 8.1_
  - [x] 7.3 Create `examples/basic/main.tf`
    - Configure AWS provider with `var.region`
    - Use `data.aws_availability_zones` to get 3 AZs
    - Call root module with single "workload" pool (10.0.0.0/16, locale = var.region, allocation_default_netmask_length = 20)
    - Create `aws_vpc_ipam_preview_next_cidr` with netmask_length = 20
    - Compute subnet CIDRs via `cidrsubnets`
    - Call `cloudbuildlab/vpc/aws ~> 1.0` with previewed CIDR and subnet CIDRs
    - _Requirements: 8.1, 8.2, 8.3, 8.4_
  - [x] 7.4 Create `examples/basic/outputs.tf`
    - Output `ipam_id`, `pool_id`, `previewed_vpc_cidr`, `vpc_id`, `vpc_cidr`
    - _Requirements: 8.5_
  - [x] 7.5 Create `examples/basic/README.md`
    - Document what the example demonstrates, apply order, destroy order, and cloudbuildlab integration note
    - _Requirements: 8.3_

- [x] 8. Checkpoint — Verify example syntax
  - Run `terraform validate` on `examples/basic/`
  - Confirm previewed CIDR and subnet CIDR computation logic is correct
  - Ask the user if questions arise before writing tests

- [x] 9. Create Terraform tests
  - [x] 9.1 Create `tests/ipam.tftest.hcl` with mock provider — create=false test
    - Configure mock provider block for `hashicorp/aws`
    - Test with `create = false`, assert 0 resources planned
    - _Requirements: 1.4, 10.1_
  - [x] 9.2 Add to `tests/ipam.tftest.hcl` — single pool test
    - Test with one pool ("workload", cidr = ["10.0.0.0/16"]), assert 1 pool + 1 pool_cidr planned
    - Verify `pool_ids["workload"]` is present in outputs
    - _Requirements: 3.1, 3.3, 10.2, 10.5_
  - [x] 9.3 Add to `tests/ipam.tftest.hcl` — nested 2-level pools test
    - Test with parent + child pool, verify parent `source_ipam_pool_id` is null, child references parent pool
    - _Requirements: 2.3, 2.4, 3.2, 10.3_
  - [x] 9.4 Add to `tests/ipam.tftest.hcl` — nested 3-level pools test
    - Test with grandparent/parent/child pool hierarchy, verify all three levels are created and parent_key chain is correct
    - Test that a child with no locale inherits `implied_locale` from grandparent when parent also has no locale
    - _Requirements: 2.5, 2.7, 3.2_
  - [x] 9.5 Add to `tests/ipam.tftest.hcl` — RAM share test
    - Test with `ram_share_principals` set, verify RAM share + association + principal resources are planned
    - _Requirements: 4.1, 4.4, 10.4_

- [x] 10. Create README and documentation
  - [x] 10.1 Update `README.md` with module documentation
    - Document submodules table, usage example (basic pools map), behaviour notes (create=false, create_ipam=false, RAM conditional, single address family)
    - Reference examples
    - _Requirements: 9.5_
  - [x] 10.2 Ensure `.terraform-docs.yaml` generates inputs/outputs tables
    - Configure terraform-docs for auto-generated variable and output documentation
    - _Requirements: 9.3_

- [x] 11. Final checkpoint — Full validation
  - Run `terraform validate` on root, submodules, and example
  - Run `terraform test` in `tests/` with mock provider; all test runs must pass
  - Verify all file structure matches spec layout (modules/, examples/, tests/, versions.tf, etc.)
  - Ask the user if any tests fail or questions arise

## Notes

- All tasks use HCL (Terraform's native language) — no language selection needed
- The module follows tfstack convention: root module is orchestrator only, no direct AWS resources
- Pool flattening is the most complex logic — pay attention to parent_key references and locale coalescing
- RAM share name sanitization (`/` → `-`) is important for AWS naming constraints
- Terraform test with mock providers validates plan-time behaviour without AWS credentials
- Checkpoints ensure incremental validation between logical phases
- Tasks marked with `*` would be optional, but none are marked here since terraform tests are considered essential for this module
