locals {
  # Current environment, 'production' by default.
  environment = get_env("ENV", "production")

  config = yamldecode(file(find_in_parent_folders(format("configs/%s/config.yaml", local.environment))))
}

generate "provider" {
  path      = "generated_provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF2
provider "ovh" {
  endpoint = "${local.config.ovh.endpoint}"
}
EOF2
}

remote_state {
  backend = "s3"
  config = {
    bucket = local.config.remote_state.bucket
    key    = "${format("%s/%s", local.environment, path_relative_to_include())}/terraform.tfstate"
    region = local.config.remote_state.region
    endpoints = {
      s3 = local.config.remote_state.endpoint
    }

    # S3-compatible backend outside AWS: skip the AWS-specific validations.
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }

  # The bucket is created by hand: terragrunt must not try to provision it.
  disable_init = true

  generate = {
    path      = "generated_backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# No `generate "versions"` block: each module declares its own
# `required_providers` in versions.tf.
