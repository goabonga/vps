# infra
| version 0.0.0

OVHcloud infrastructure managed with Terragrunt and OpenTofu.

## Layout

```
configs/<env>/config.yaml   # values of an environment (ENV, default: production)
modules/vps/                # Terraform module around ovh_vps
ovh/root.hcl                # root: ovh provider, S3 backend (OVHcloud Object Storage)
ovh/vps/terragrunt.hcl      # the VPS unit
```
