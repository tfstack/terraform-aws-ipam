# Implementation Tasks: Multi-Account IPAM Example

Architecture rationale: [WALKTHROUGH.md](WALKTHROUGH.md).

## Phase 1 — Initial implementation (complete)

- [x] Create `org-bootstrap/` — delegation + RAM org sharing
- [x] Create `ipam/` — IPAM module, pools, RAM shares
- [x] Create `workload-a/` and `workload-b/` — VPC from shared pool
- [x] Create `README.md`, `FINDINGS.md`, `.gitignore`
- [x] Document apply/destroy order and profiles

## Phase 2 — Multi-region ANZ expansion (complete)

- [x] Restructure `ipam/` pools: `org` → `nz`/`au` → `dev`/`sandbox`
- [x] Add `primary_region` / `secondary_region` variables (defaults ap-southeast-6 / ap-southeast-2)
- [x] Rename outputs: `nz_dev_pool_id`, `au_sandbox_pool_id`, `operating_regions`
- [x] Workload-a: region ap-southeast-6; workload-b: region ap-southeast-2
- [x] Add demo EC2 (t3.nano) with static private IP `.5` per workload
- [x] Update README, FINDINGS, root README
- [x] Rewrite Kiro spec: WALKTHROUGH.md, requirements.md, design.md, tasks.md

## Phase 3 — Pool-backed VPC and walkthrough (complete)

- [x] Add `modules/ipam-vpc/` — `ipv4_ipam_pool_id`, subnets from allocated VPC CIDR
- [x] Replace `cloudbuildlab/vpc/aws` in workload stacks with `ipam-vpc` module
- [x] Remove `pool_cidr` and `previewed_vpc_cidr` from workload stacks
- [x] Expand WALKTHROUGH: Planning vs Monitoring, RAM console, dashboard sync, ENI visibility
- [x] Sync requirements.md and design.md with pool-backed pattern

## Validation

```bash
terraform fmt -recursive examples/multi-account/
for stack in org-bootstrap ipam workload-a workload-b modules/ipam-vpc; do
  terraform -chdir=examples/multi-account/$stack init -backend=false -input=false
  terraform -chdir=examples/multi-account/$stack validate
done
```

Before commit, confirm no real account or resource IDs in staged files:

```bash
git diff --cached | rg '[0-9]{12}'   # should only hit placeholder patterns in examples
git status                           # no terraform.tfvars staged
```

## Apply order

1. `org-bootstrap/` — `ipam-org`
2. `ipam/` — `ipam-network`
3. `workload-a/` + `workload-b/` — parallel OK

## Destroy order

1. `workload-a/`, `workload-b/`
2. `ipam/`
3. `org-bootstrap/` delegation typically left in place
