# bootstrap
| version 0.0.0

Creates what the other units need to store their state: the Public Cloud
project (or uses an existing one), a user with the Object Storage operator
role, its S3 credentials and policy, the versioned state bucket, and an optional
OAuth2 service account with its IAM policies. It is run by hand with
`scripts/bootstrap.sh`, see [infra/README.md](../../README.md#bootstrapping-the-state-storage).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_ovh"></a> [ovh](#requirement\_ovh) | ~> 2.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_ovh"></a> [ovh](#provider\_ovh) | ~> 2.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [ovh_cloud_project.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/cloud_project) | resource |
| [ovh_cloud_project_user.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/cloud_project_user) | resource |
| [ovh_cloud_project_user_s3_credential.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/cloud_project_user_s3_credential) | resource |
| [ovh_cloud_project_user_s3_policy.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/cloud_project_user_s3_policy) | resource |
| [ovh_cloud_storage_object_bucket.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/cloud_storage_object_bucket) | resource |
| [ovh_iam_policy.account](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/iam_policy) | resource |
| [ovh_iam_policy.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/iam_policy) | resource |
| [ovh_me_api_oauth2_client.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/me_api_oauth2_client) | resource |
| [ovh_me.account](https://registry.terraform.io/providers/ovh/ovh/latest/docs/data-sources/me) | data source |
| [ovh_me.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/data-sources/me) | data source |
| [ovh_order_cart.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/data-sources/order_cart) | data source |
| [ovh_order_cart_product_plan.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/data-sources/order_cart_product_plan) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket_encryption"></a> [bucket\_encryption](#input\_bucket\_encryption) | Server-side encryption algorithm of the bucket (AES256 or PLAINTEXT). | `string` | `"AES256"` | no |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Name of the Object Storage bucket holding the Terraform states. | `string` | n/a | yes |
| <a name="input_bucket_region"></a> [bucket\_region](#input\_bucket\_region) | Region of the bucket (e.g. gra); upper-cased for the API. | `string` | n/a | yes |
| <a name="input_bucket_tags"></a> [bucket\_tags](#input\_bucket\_tags) | Tags of the bucket. | `map(string)` | <pre>{<br/>  "managed_by": "terragrunt",<br/>  "purpose": "terraform-state"<br/>}</pre> | no |
| <a name="input_bucket_versioning"></a> [bucket\_versioning](#input\_bucket\_versioning) | Enable versioning on the bucket, to recover previous states. | `bool` | `true` | no |
| <a name="input_iam_policies"></a> [iam\_policies](#input\_iam\_policies) | IAM policies granted to the OAuth2 client, by name: the URNs of the<br/>resources and the actions allowed on them (e.g. vps:apiovh:*). Ignored<br/>when oauth2\_client is null. | <pre>map(object({<br/>    resources = list(string)<br/>    allow     = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_oauth2_client"></a> [oauth2\_client](#input\_oauth2\_client) | Creates an OAuth2 service account (client credentials flow) for the<br/>day-to-day Terragrunt runs, so they do not need the bootstrap<br/>credentials. Null creates none. It has no right until iam\_policies<br/>grants some. | <pre>object({<br/>    name        = string<br/>    description = optional(string, "Terragrunt runs of ovh-tf")<br/>  })</pre> | `null` | no |
| <a name="input_order_project"></a> [order\_project](#input\_order\_project) | Orders a new Public Cloud project instead of using an existing one.<br/>Needs a default payment method on the OVHcloud account. `ovh_subsidiary`<br/>defaults to the one of the account. | <pre>object({<br/>    description    = string<br/>    ovh_subsidiary = optional(string)<br/>    plan_code      = optional(string, "project.2018")<br/>  })</pre> | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Id of an existing Public Cloud project. Exactly one of project\_id and order\_project must be set. | `string` | `null` | no |
| <a name="input_user_description"></a> [user\_description](#input\_user\_description) | Description of the user that accesses the bucket. | `string` | `"terraform state"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_access_key_id"></a> [access\_key\_id](#output\_access\_key\_id) | S3 access key id (AWS\_ACCESS\_KEY\_ID). |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Name of the state bucket. |
| <a name="output_oauth2_client_id"></a> [oauth2\_client\_id](#output\_oauth2\_client\_id) | Client id of the OAuth2 service account (OVH\_CLIENT\_ID); null when none. |
| <a name="output_oauth2_client_secret"></a> [oauth2\_client\_secret](#output\_oauth2\_client\_secret) | Client secret of the OAuth2 service account (OVH\_CLIENT\_SECRET); null when none. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | Id of the Public Cloud project. |
| <a name="output_secret_access_key"></a> [secret\_access\_key](#output\_secret\_access\_key) | S3 secret access key (AWS\_SECRET\_ACCESS\_KEY). |
| <a name="output_user_id"></a> [user\_id](#output\_user\_id) | Id of the user that accesses the bucket. |
<!-- END_TF_DOCS -->
