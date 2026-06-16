mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "ap-southeast-2"
    }
  }

  mock_resource "aws_vpc_ipam" {
    defaults = {
      id                       = "ipam-1234567890abcdef0"
      arn                      = "arn:aws:ec2:ap-southeast-2:123456789012:ipam/ipam-1234567890abcdef0"
      private_default_scope_id = "ipam-scope-private-1234567890abcdef0"
      public_default_scope_id  = "ipam-scope-public-1234567890abcdef0"
    }
  }

  mock_resource "aws_vpc_ipam_pool" {
    defaults = {
      id     = "ipam-pool-1234567890abcdef0"
      arn    = "arn:aws:ec2:ap-southeast-2:123456789012:ipam-pool/ipam-pool-1234567890abcdef0"
      locale = "ap-southeast-2"
    }
  }

  mock_resource "aws_vpc_ipam_pool_cidr" {
    defaults = {
      id   = "ipam-pool-cidr-1234567890abcdef0"
      cidr = "10.0.0.0/16"
    }
  }

  mock_resource "aws_ram_resource_share" {
    defaults = {
      id   = "arn:aws:ram:ap-southeast-2:123456789012:resource-share/share-1234567890abcdef0"
      arn  = "arn:aws:ram:ap-southeast-2:123456789012:resource-share/share-1234567890abcdef0"
      name = "workload"
    }
  }

  mock_resource "aws_ram_resource_association" {}

  mock_resource "aws_ram_principal_association" {}
}

run "create_false" {
  command = plan

  variables {
    create = false
    pools = {
      workload = {
        cidr = ["10.0.0.0/16"]
      }
    }
  }

  assert {
    condition     = length(keys(output.pool_ids)) == 0
    error_message = "create = false should produce no pool outputs"
  }

  assert {
    condition     = output.ipam_id == null
    error_message = "create = false should not create an IPAM instance"
  }
}

run "single_pool" {
  command = apply

  variables {
    pools = {
      workload = {
        cidr   = ["10.0.0.0/16"]
        locale = "ap-southeast-2"
      }
    }
  }

  assert {
    condition     = length(keys(output.pool_ids)) == 1
    error_message = "Expected exactly one pool to be created"
  }

  assert {
    condition     = output.pool_ids["workload"] != null
    error_message = "pool_ids[\"workload\"] should be present in outputs"
  }
}

run "nested_two_level_pools" {
  command = apply

  variables {
    pools = {
      core = {
        cidr = ["10.0.0.0/8"]
        sub_pools = {
          prod = {
            cidr = ["10.1.0.0/16"]
          }
        }
      }
    }
  }

  assert {
    condition     = length(keys(output.pool_ids)) == 2
    error_message = "Expected two pools for nested hierarchy"
  }

  assert {
    condition     = output.pools["core"].source_ipam_pool_id == null
    error_message = "Parent pool should have null source_ipam_pool_id"
  }

  assert {
    condition     = output.pools["core/prod"].source_ipam_pool_id == output.pool_ids["core"]
    error_message = "Child pool should reference parent pool ID"
  }
}

run "nested_three_level_pools" {
  command = apply

  variables {
    pools = {
      core = {
        cidr   = ["10.0.0.0/8"]
        locale = "eu-west-1"
        sub_pools = {
          region = {
            cidr = ["10.1.0.0/16"]
            sub_pools = {
              team = {
                cidr = ["10.1.1.0/24"]
              }
            }
          }
        }
      }
    }
  }

  assert {
    condition     = length(keys(output.pool_ids)) == 3
    error_message = "Expected three pools for 3-level hierarchy"
  }

  assert {
    condition     = output.pools["core/region/team"].locale == "eu-west-1"
    error_message = "L3 pool without locale should inherit implied locale from ancestor"
  }
}

run "nested_five_level_pools" {
  command = apply

  variables {
    pools = {
      core = {
        cidr   = ["10.0.0.0/8"]
        locale = "ap-southeast-2"
        sub_pools = {
          region = {
            cidr = ["10.1.0.0/16"]
            sub_pools = {
              env = {
                cidr = ["10.1.0.0/20"]
                sub_pools = {
                  team = {
                    cidr = ["10.1.0.0/22"]
                    sub_pools = {
                      app = {
                        cidr = ["10.1.0.0/24"]
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  assert {
    condition     = length(keys(output.pool_ids)) == 5
    error_message = "Expected five pools for 5-level hierarchy"
  }

  assert {
    condition     = output.pools["core/region/env/team/app"].source_ipam_pool_id == output.pool_ids["core/region/env/team"]
    error_message = "L5 pool should reference L4 parent pool ID"
  }

  assert {
    condition     = output.pools["core/region/env/team/app"].locale == "ap-southeast-2"
    error_message = "L5 pool without locale should inherit implied locale from ancestors"
  }
}

run "ram_share" {
  command = apply

  variables {
    pools = {
      workload = {
        cidr                 = ["10.0.0.0/16"]
        locale               = "ap-southeast-2"
        ram_share_principals = ["arn:aws:organizations::123456789012:ou/o-abc/ou-def"]
      }
    }
  }

  assert {
    condition     = contains(output.ram_share_pool_keys, "workload")
    error_message = "Expected RAM share for workload pool when ram_share_principals is set"
  }
}
