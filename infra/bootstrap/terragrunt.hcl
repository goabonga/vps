# Standalone unit (no include of ovh/root.hcl): it creates the bucket that
# holds every other state, so it cannot use that bucket from the start.
#
#   BOOTSTRAP_BACKEND=local (default)  state in bootstrap/terraform.tfstate
#   BOOTSTRAP_BACKEND=s3               state in the bucket it created
#
# scripts/bootstrap.sh drives the switch from one to the other.

locals {
  environment = get_env("ENV", "production")

  config = yamldecode(file(find_in_parent_folders(format("configs/%s/config.yaml", local.environment))))

  use_s3 = get_env("BOOTSTRAP_BACKEND", "local") == "s3"

  backend_local = <<-EOT
    terraform {
      backend "local" {
        path = "${get_terragrunt_dir()}/terraform.tfstate"
      }
    }
  EOT

  backend_s3 = <<-EOT
    terraform {
      backend "s3" {
        bucket = "${local.config.remote_state.bucket}"
        key    = "${local.environment}/bootstrap/terraform.tfstate"
        region = "${local.config.remote_state.region}"
        endpoints = {
          s3 = "${local.config.remote_state.endpoint}"
        }

        skip_credentials_validation = true
        skip_region_validation      = true
        skip_requesting_account_id  = true
        skip_metadata_api_check     = true
        skip_s3_checksum            = true
        use_path_style              = true
      }
    }
  EOT
}

generate "provider" {
  path      = "generated_provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOT
    provider "ovh" {
      endpoint = "${local.config.ovh.endpoint}"
    }
  EOT
}

generate "backend" {
  path      = "generated_backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = local.use_s3 ? local.backend_s3 : local.backend_local
}

terraform {
  source = "../modules/bootstrap"
}

# The state bucket is the one named in remote_state; the other keys under
# `bootstrap:` in configs/<env>/config.yaml are module variables. The id of the
# Public Cloud project is read from OVH_PROJECT_ID, so it is not committed.
inputs = merge(local.config.bootstrap, {
  bucket_name   = local.config.remote_state.bucket
  bucket_region = local.config.remote_state.region
  project_id    = get_env("OVH_PROJECT_ID", "") == "" ? null : get_env("OVH_PROJECT_ID")
})
