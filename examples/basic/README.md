# Basic IPAM Example

This example creates an IPAM instance with a single `workload` pool, previews a VPC CIDR from that pool, and provisions a VPC using the `cloudbuildlab/vpc/aws` module.

## What it demonstrates

- Root module usage with a single pool
- `aws_vpc_ipam_preview_next_cidr` to allocate a VPC-sized CIDR from a pool
- Public and private subnet CIDR computation via `cidrsubnets`
- Integration with `cloudbuildlab/vpc/aws ~> 1.0`

## Apply order

1. IPAM instance and pool are created via the root module
2. Next CIDR is previewed from the workload pool (output as `previewed_vpc_cidr`)
3. VPC and subnets are created using the expected first `/20` from the pool

Subnet CIDRs are computed from the expected VPC CIDR at plan time. The VPC module uses `length()` on subnet lists for `count`, which requires known values during `terraform plan`. For a fresh pool with a single provisioned `/16`, the first previewed `/20` matches `cidrsubnet("10.0.0.0/16", 4, 0)` — compare `previewed_vpc_cidr` and `vpc_cidr` outputs after apply.

## Destroy order

Destroy in reverse: VPC resources first, then IPAM pools and the IPAM instance. Terraform dependency ordering handles this when using `terraform destroy` on the full configuration.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Notes

- Requires AWS credentials with permissions for IPAM, VPC, and RAM (if sharing pools)
- The `cloudbuildlab/vpc/aws` module is an example-only dependency; it is not required by the root IPAM module
