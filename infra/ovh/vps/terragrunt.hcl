include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  config = include.root.locals.config
}

terraform {
  source = "../../modules/vps"
}

# The keys under `vps:` in configs/<env>/config.yaml are the module
# variables (see modules/vps/variables.tf).
inputs = local.config.vps
