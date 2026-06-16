# Requirements Document

## Introduction

This document defines the requirements for the `terraform-aws-ipam` Terraform module. The module provides AWS VPC IPAM (IP Address Manager) management with hierarchical IPv4 pool support, optional RAM sharing, and an orchestrator-only root module pattern following tfstack conventions.

## Glossary

- **Root_Module**: The top-level Terraform module that acts as an orchestrator, containing no AWS resources directly
- **IPAM_Core**: The submodule responsible for creating the AWS VPC IPAM instance and configuring operating regions
- **Pool_Module**: The submodule responsible for creating a single pool node with CIDR provisioning and optional RAM sharing
- **Flatten_Logic**: The local computation that transforms nested pool maps into a flat map with parent references
- **Operating_Regions**: The list of AWS regions where the IPAM operates, derived from pool locales plus the current region
- **Scope_ID**: The IPAM scope identifier used to attach pools (private or public)
- **RAM_Share**: AWS Resource Access Manager share that allows cross-account pool access
- **Pool_Key**: The path-based key identifying a pool in the flat map (e.g., "workload/us-east-1/prod")
- **Parent_Key**: A reference from a child pool to its parent pool's key in the flat map

## Requirements

### Requirement 1: IPAM Instance Creation

**User Story:** As a platform engineer, I want to create an AWS VPC IPAM instance with appropriate operating regions, so that I can manage IP address allocation across my organization.

#### Acceptance Criteria

1. WHEN `create = true` AND `create_ipam = true`, THE IPAM_Core SHALL create one `aws_vpc_ipam` resource
2. WHEN an IPAM is created, THE IPAM_Core SHALL configure operating regions from the derived list that includes the current AWS region and all unique pool locales
3. THE IPAM_Core SHALL expose the IPAM ID, ARN, private default scope ID, and public default scope ID as outputs
4. WHEN `create = false`, THE Root_Module SHALL create zero AWS resources across all submodules
5. WHEN `create_ipam = false`, THE Root_Module SHALL skip IPAM creation and use the provided `ipam_scope_id` for pool attachment

### Requirement 2: Pool Hierarchy Flattening

**User Story:** As a platform engineer, I want to define pools in a nested structure (up to 3 levels), so that I can express hierarchical IP address allocation in an intuitive way.

#### Acceptance Criteria

1. THE Flatten_Logic SHALL transform the nested `pools` variable into a flat map keyed by path (e.g., "workload", "workload/us-east-1", "workload/us-east-1/prod")
2. WHEN flattening pools, THE Flatten_Logic SHALL preserve all pool attributes from the nested input without loss
3. WHEN flattening pools, THE Flatten_Logic SHALL assign `parent_key = null` to all level-1 pools
4. WHEN flattening pools, THE Flatten_Logic SHALL assign `parent_key` for level-2 pools referencing their level-1 parent key
5. WHEN flattening pools, THE Flatten_Logic SHALL assign `parent_key` for level-3 pools referencing their level-2 parent key
6. THE Flatten_Logic SHALL produce a flat map whose size equals the total number of pool definitions across all levels in the input
7. WHEN a child pool does not specify a locale, THE Flatten_Logic SHALL resolve `implied_locale` by coalescing the child locale, parent locale, and grandparent locale

### Requirement 3: Pool Resource Creation

**User Story:** As a platform engineer, I want each pool in my hierarchy to be created as an AWS IPAM pool with provisioned CIDRs, so that I can allocate IP ranges from them.

#### Acceptance Criteria

1. WHEN `create = true`, THE Pool_Module SHALL create one `aws_vpc_ipam_pool` resource per entry in the flat pools map
2. THE Pool_Module SHALL set `source_ipam_pool_id` to the parent pool's ID when `parent_key` is non-null, and to null when `parent_key` is null
3. THE Pool_Module SHALL provision CIDRs by creating one `aws_vpc_ipam_pool_cidr` resource for each entry in the pool's `cidr` list
4. THE Pool_Module SHALL pass through all optional allocation parameters (default/min/max netmask length, resource tags, auto_import) to the pool resource
5. THE Pool_Module SHALL expose pool ID, ARN, locale, and provisioned CIDRs as outputs

### Requirement 4: RAM Share Management

**User Story:** As a platform engineer, I want to optionally share IPAM pools with other AWS accounts or OUs via RAM, so that I can enable cross-account IP allocation.

#### Acceptance Criteria

1. WHEN `ram_share_principals` is a non-empty list AND `create = true`, THE Pool_Module SHALL create one `aws_ram_resource_share` resource
2. WHEN a RAM share is created, THE Pool_Module SHALL create one `aws_ram_resource_association` linking the pool to the share
3. WHEN a RAM share is created, THE Pool_Module SHALL create one `aws_ram_principal_association` for each entry in `ram_share_principals`
4. WHEN `ram_share_principals` is empty, THE Pool_Module SHALL create zero RAM resources
5. WHEN creating a RAM share name, THE Pool_Module SHALL replace all `/` characters in the pool key with `-`

### Requirement 5: Operating Regions Derivation

**User Story:** As a platform engineer, I want the IPAM operating regions to be automatically derived from my pool configuration, so that I don't need to manually maintain a separate region list.

#### Acceptance Criteria

1. THE Root_Module SHALL always include the current AWS region (provider region) in the operating regions list
2. THE Root_Module SHALL include all unique non-null locale values from pool definitions in the operating regions list
3. THE Root_Module SHALL deduplicate the operating regions list so no region appears more than once

### Requirement 6: Scope Resolution

**User Story:** As a platform engineer, I want the module to resolve the correct IPAM scope ID based on my configuration, so that pools are attached to the right scope.

#### Acceptance Criteria

1. WHEN `create_ipam = true` AND `scope_type = "private"`, THE Root_Module SHALL use the private default scope ID from the created IPAM
2. WHEN `create_ipam = true` AND `scope_type = "public"`, THE Root_Module SHALL use the public default scope ID from the created IPAM
3. WHEN `create_ipam = false`, THE Root_Module SHALL use the value of `var.ipam_scope_id` as the scope ID

### Requirement 7: Root Module Outputs

**User Story:** As a platform engineer, I want structured outputs from the module, so that downstream VPC modules can reference pool IDs and other attributes.

#### Acceptance Criteria

1. THE Root_Module SHALL output the IPAM ID (null if not created)
2. THE Root_Module SHALL output the IPAM ARN
3. THE Root_Module SHALL output the private scope ID
4. THE Root_Module SHALL output a `pools` map keyed by path containing id, arn, locale, and cidr for each pool
5. THE Root_Module SHALL output a `pool_ids` map keyed by path containing only the pool ID (convenience output)

### Requirement 8: Example Implementation

**User Story:** As a module consumer, I want a working example showing IPAM with a VPC, so that I can understand how to integrate this module.

#### Acceptance Criteria

1. THE Example SHALL create an IPAM with a single "workload" pool using the root module
2. THE Example SHALL use `aws_vpc_ipam_preview_next_cidr` to obtain a VPC CIDR from the pool
3. THE Example SHALL create a VPC using the `cloudbuildlab/vpc/aws` module with the previewed CIDR
4. THE Example SHALL compute public and private subnet CIDRs using `cidrsubnets`
5. THE Example SHALL output the IPAM ID, pool ID, previewed VPC CIDR, VPC ID, and VPC CIDR

### Requirement 9: Repository Standards

**User Story:** As a module maintainer, I want the repository to follow tfstack conventions, so that it is consistent with other modules in the organization.

#### Acceptance Criteria

1. THE Root_Module SHALL contain no direct AWS resource declarations (orchestrator-only pattern)
2. THE Root_Module SHALL declare `terraform >= 1.3` and `aws >= 5.0` version constraints in `versions.tf`
3. THE Repository SHALL include a `.terraform-docs.yaml` configuration for documentation generation
4. THE Repository SHALL include a `.gitignore` file appropriate for Terraform modules
5. THE Repository SHALL include a README documenting submodules, usage, and behaviour

### Requirement 10: Terraform Testing

**User Story:** As a module maintainer, I want automated tests validating module behaviour, so that I can catch regressions early.

#### Acceptance Criteria

1. WHEN `create = false` is passed, THE Test_Suite SHALL verify zero resources are planned
2. WHEN a single pool is defined, THE Test_Suite SHALL verify one pool and one pool CIDR are planned
3. WHEN nested 2-level pools are defined, THE Test_Suite SHALL verify the child pool references the parent pool ID
4. WHEN `ram_share_principals` is set on a pool, THE Test_Suite SHALL verify RAM resources are planned
5. THE Test_Suite SHALL verify that `pool_ids["workload"]` is present in outputs for a basic pool configuration
