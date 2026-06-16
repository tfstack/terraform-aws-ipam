# terraform-aws-ipam

Terraform module for AWS VPC IPAM (IP Address Manager) with hierarchical IPv4 pools (up to 5 levels), optional RAM sharing, and an orchestrator-only root module.

## Features

- Creates an IPAM instance with operating regions derived from pool locales and the current AWS region
- Defines pools in a nested `pools` map; the root module flattens it into path keys such as `core`, `core/prod`, and `core/prod/team-a`
- Chains child pools to parents via `source_ipam_pool_id`
- Optionally shares pools with other accounts or OUs through AWS RAM
- Attaches pools to an existing IPAM scope when `create_ipam = false`

## Architecture

The root module contains **no direct AWS resources**. It delegates to two submodules:

| Submodule | Responsibility |
| --- | --- |
| [`modules/ipam-core`](modules/ipam-core/) | Creates `aws_vpc_ipam` and configures operating regions |
| [`modules/pool`](modules/pool/) | Creates all pools, pool CIDRs, and optional RAM shares from a flattened pool map |

Pool hierarchy is flattened in root `locals` (`l1_pools` … `l5_pools` → `flat_pools`). The pool submodule creates level-1 through level-5 `aws_vpc_ipam_pool` resources separately so parent/child references resolve without Terraform dependency cycles.

## Usage

### Basic — single pool

```hcl
module "ipam" {
  source = "tfstack/ipam/aws"

  pools = {
    workload = {
      cidr                              = ["10.0.0.0/16"]
      locale                            = "eu-west-1"
      allocation_default_netmask_length = 20
      description                       = "Workload pool"
    }
  }

  tags = {
    Environment = "production"
  }
}

# Reference a pool by path key
output "workload_pool_id" {
  value = module.ipam.pool_ids["workload"]
}
```

### Advanced — nested pools with RAM sharing

```hcl
module "ipam" {
  source = "tfstack/ipam/aws"

  pools = {
    core = {
      cidr   = ["10.0.0.0/8"]
      locale = "us-east-1"
      sub_pools = {
        prod = {
          cidr                 = ["10.1.0.0/16"]
          locale               = "us-east-1"
          ram_share_principals = ["arn:aws:organizations::123456789012:ou/o-abc/ou-def"]
          sub_pools = {
            team-a = {
              cidr   = ["10.1.0.0/20"]
              locale = "us-east-1"
            }
          }
        }
      }
    }
  }
}
```

### Attach pools to an existing IPAM

```hcl
module "ipam" {
  source = "tfstack/ipam/aws"

  create_ipam   = false
  ipam_scope_id = "ipam-scope-0123456789abcdef0"

  pools = {
    workload = {
      cidr = ["10.0.0.0/16"]
    }
  }
}
```

## Pool hierarchy

Pools are defined in a nested map with up to five levels using `sub_pools`:

```text
pools
├── core                         → flat key: "core"
│   └── region                   → flat key: "core/region"
│       └── env                  → flat key: "core/region/env"
│           └── team             → flat key: "core/region/env/team"
│               └── app          → flat key: "core/region/env/team/app"
```

- **Path keys** are built by joining map keys with `/`. Keys at any level must not contain `/`.
- **`locale`** is optional on child pools. When omitted, the module resolves `implied_locale` from the nearest ancestor.
- **`ram_share_principals`** is optional per pool. RAM resources are created only when this list is non-empty.

## Behaviour

| Input | Effect |
| --- | --- |
| `create = false` | Creates zero AWS resources across all submodules |
| `create_ipam = false` | Skips IPAM creation; pools attach to `ipam_scope_id` |
| `scope_type = "private"` | Uses the private default scope from a newly created IPAM (default) |
| `scope_type = "public"` | Uses the public default scope from a newly created IPAM |
| `address_family` | Global default applied to all pools (default `"ipv4"`) |

Operating regions are always derived automatically: the current AWS provider region plus every unique non-null `locale` from pool definitions.

RAM share names use the flat pool path with `/` replaced by `-` (for example, `core/prod` → `core-prod`).

## Examples

See [`examples/basic`](examples/basic/) for an end-to-end example that:

1. Creates an IPAM with a `workload` pool
2. Previews the next VPC CIDR with `aws_vpc_ipam_preview_next_cidr`
3. Provisions a VPC and subnets using [`cloudbuildlab/vpc/aws`](https://registry.terraform.io/modules/cloudbuildlab/vpc/aws/latest)

## Requirements

| Name | Version |
| --- | --- |
| [terraform](https://www.terraform.io/downloads.html) | >= 1.3 |
| [aws](https://registry.terraform.io/providers/hashicorp/aws/latest) | >= 5.0 |

Running `terraform test` with mock providers requires **Terraform >= 1.7**.

## Testing

```bash
terraform init
terraform test
```

Tests in [`tests/ipam.tftest.hcl`](tests/ipam.tftest.hcl) use the Terraform test framework with a mock AWS provider. They validate module wiring and outputs without creating real infrastructure or requiring AWS credentials.

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | --- |
| `create` | Whether to create IPAM and pool resources | `bool` | `true` | no |
| `create_ipam` | Whether to create a new IPAM instance. When `false`, set `ipam_scope_id` | `bool` | `true` | no |
| `ipam_scope_id` | Existing IPAM scope ID when `create_ipam = false` | `string` | `null` | no |
| `scope_type` | Scope to use when creating IPAM: `"private"` or `"public"` | `string` | `"private"` | no |
| `address_family` | Address family applied to all pools | `string` | `"ipv4"` | no |
| `description` | Description of the IPAM instance | `string` | `null` | no |
| `pools` | Nested pool definitions (max depth 5). See [Pool hierarchy](#pool-hierarchy) | `map(object)` | `{}` | no |
| `tags` | Tags applied to created resources | `map(string)` | `{}` | no |

### `pools` object attributes

Available at each level (L1 through L5 via nested `sub_pools`; L5 is the leaf level):

| Attribute | Description | Required |
| --- | --- | --- |
| `cidr` | CIDR blocks to provision in the pool | yes |
| `locale` | AWS region locale for the pool | no |
| `description` | Pool description | no |
| `allocation_default_netmask_length` | Default allocation netmask length | no |
| `allocation_min_netmask_length` | Minimum allocation netmask length | no |
| `allocation_max_netmask_length` | Maximum allocation netmask length | no |
| `allocation_resource_tags` | Tags applied to resources allocated from the pool | no |
| `auto_import` | Whether to auto-import discovered CIDRs | no |
| `ram_share_principals` | Principal ARNs to share the pool with via RAM | no |
| `sub_pools` | Child pools (not available at L5) | no |

## Outputs

| Name | Description |
| --- | --- |
| `ipam_id` | ID of the created IPAM instance (`null` when not created) |
| `ipam_arn` | ARN of the created IPAM instance (`null` when not created) |
| `private_scope_id` | Private default scope ID of the created IPAM (`null` when not created) |
| `pools` | Map of pool attributes keyed by path (`id`, `arn`, `locale`, `cidr`, `source_ipam_pool_id`) |
| `pool_ids` | Map of pool IDs keyed by path (convenience output) |
| `ram_share_pool_keys` | Pool path keys that have RAM shares configured |

## Submodule documentation

Inputs and outputs for each submodule are defined in:

- [`modules/ipam-core/variables.tf`](modules/ipam-core/variables.tf) / [`outputs.tf`](modules/ipam-core/outputs.tf)
- [`modules/pool/variables.tf`](modules/pool/variables.tf) / [`outputs.tf`](modules/pool/outputs.tf)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ipam_core"></a> [ipam\_core](#module\_ipam\_core) | ./modules/ipam-core | n/a |
| <a name="module_pool"></a> [pool](#module\_pool) | ./modules/pool | n/a |

## Resources

| Name | Type |
|------|------|

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_address_family"></a> [address\_family](#input\_address\_family) | Address family applied to all pools. | `string` | `"ipv4"` | no |
| <a name="input_create"></a> [create](#input\_create) | Whether to create IPAM and pool resources. | `bool` | `true` | no |
| <a name="input_create_ipam"></a> [create\_ipam](#input\_create\_ipam) | Whether to create a new IPAM instance. When false, provide ipam\_scope\_id. | `bool` | `true` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the IPAM instance. | `string` | `null` | no |
| <a name="input_ipam_scope_id"></a> [ipam\_scope\_id](#input\_ipam\_scope\_id) | Existing IPAM scope ID to attach pools to when create\_ipam is false. | `string` | `null` | no |
| <a name="input_pools"></a> [pools](#input\_pools) | Nested pool definitions. Max depth 5. | <pre>map(object({<br/>    cidr                              = list(string)<br/>    locale                            = optional(string)<br/>    description                       = optional(string)<br/>    allocation_default_netmask_length = optional(number)<br/>    allocation_min_netmask_length     = optional(number)<br/>    allocation_max_netmask_length     = optional(number)<br/>    allocation_resource_tags          = optional(map(string))<br/>    auto_import                       = optional(bool)<br/>    ram_share_principals              = optional(list(string))<br/>    sub_pools = optional(map(object({<br/>      cidr                              = list(string)<br/>      locale                            = optional(string)<br/>      description                       = optional(string)<br/>      allocation_default_netmask_length = optional(number)<br/>      allocation_min_netmask_length     = optional(number)<br/>      allocation_max_netmask_length     = optional(number)<br/>      allocation_resource_tags          = optional(map(string))<br/>      auto_import                       = optional(bool)<br/>      ram_share_principals              = optional(list(string))<br/>      sub_pools = optional(map(object({<br/>        cidr                              = list(string)<br/>        locale                            = optional(string)<br/>        description                       = optional(string)<br/>        allocation_default_netmask_length = optional(number)<br/>        allocation_min_netmask_length     = optional(number)<br/>        allocation_max_netmask_length     = optional(number)<br/>        allocation_resource_tags          = optional(map(string))<br/>        auto_import                       = optional(bool)<br/>        ram_share_principals              = optional(list(string))<br/>        sub_pools = optional(map(object({<br/>          cidr                              = list(string)<br/>          locale                            = optional(string)<br/>          description                       = optional(string)<br/>          allocation_default_netmask_length = optional(number)<br/>          allocation_min_netmask_length     = optional(number)<br/>          allocation_max_netmask_length     = optional(number)<br/>          allocation_resource_tags          = optional(map(string))<br/>          auto_import                       = optional(bool)<br/>          ram_share_principals              = optional(list(string))<br/>          sub_pools = optional(map(object({<br/>            cidr                              = list(string)<br/>            locale                            = optional(string)<br/>            description                       = optional(string)<br/>            allocation_default_netmask_length = optional(number)<br/>            allocation_min_netmask_length     = optional(number)<br/>            allocation_max_netmask_length     = optional(number)<br/>            allocation_resource_tags          = optional(map(string))<br/>            auto_import                       = optional(bool)<br/>            ram_share_principals              = optional(list(string))<br/>            sub_pools = optional(map(object({<br/>              cidr                              = list(string)<br/>              locale                            = optional(string)<br/>              description                       = optional(string)<br/>              allocation_default_netmask_length = optional(number)<br/>              allocation_min_netmask_length     = optional(number)<br/>              allocation_max_netmask_length     = optional(number)<br/>              allocation_resource_tags          = optional(map(string))<br/>              auto_import                       = optional(bool)<br/>              ram_share_principals              = optional(list(string))<br/>            })))<br/>          })))<br/>        })))<br/>      })))<br/>    })))<br/>  }))</pre> | `{}` | no |
| <a name="input_scope_type"></a> [scope\_type](#input\_scope\_type) | IPAM scope type to use when creating a new IPAM instance. | `string` | `"private"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to created resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ipam_arn"></a> [ipam\_arn](#output\_ipam\_arn) | ARN of the created IPAM instance. |
| <a name="output_ipam_id"></a> [ipam\_id](#output\_ipam\_id) | ID of the created IPAM instance. |
| <a name="output_pool_ids"></a> [pool\_ids](#output\_pool\_ids) | Map of pool IDs keyed by path. |
| <a name="output_pools"></a> [pools](#output\_pools) | Map of pool attributes keyed by path. |
| <a name="output_private_scope_id"></a> [private\_scope\_id](#output\_private\_scope\_id) | Private default scope ID of the created IPAM instance. |
| <a name="output_ram_share_pool_keys"></a> [ram\_share\_pool\_keys](#output\_ram\_share\_pool\_keys) | Pool keys with RAM shares configured. |
<!-- END_TF_DOCS -->
