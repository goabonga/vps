variable "project_id" {
  description = "Id of an existing Public Cloud project. Exactly one of project_id and order_project must be set."
  type        = string
  default     = null
}

variable "order_project" {
  description = <<-EOT
    Orders a new Public Cloud project instead of using an existing one.
    Needs a default payment method on the OVHcloud account. `ovh_subsidiary`
    defaults to the one of the account.
  EOT
  type = object({
    description    = string
    ovh_subsidiary = optional(string)
    plan_code      = optional(string, "project.2018")
  })
  default = null
}

variable "bucket_name" {
  description = "Name of the Object Storage bucket holding the Terraform states."
  type        = string
}

variable "bucket_region" {
  description = "Region of the bucket (e.g. gra); upper-cased for the API."
  type        = string
}

variable "bucket_versioning" {
  description = "Enable versioning on the bucket, to recover previous states."
  type        = bool
  default     = true
}

variable "bucket_encryption" {
  description = "Server-side encryption algorithm of the bucket (AES256 or PLAINTEXT)."
  type        = string
  default     = "AES256"
}

variable "bucket_tags" {
  description = "Tags of the bucket."
  type        = map(string)
  default = {
    managed_by = "terragrunt"
    purpose    = "terraform-state"
  }
}

variable "user_description" {
  description = "Description of the user that accesses the bucket."
  type        = string
  default     = "terraform state"
}

variable "oauth2_client" {
  description = <<-EOT
    Creates an OAuth2 service account (client credentials flow) for the
    day-to-day Terragrunt runs, so they do not need the bootstrap
    credentials. Null creates none. It has no right until iam_policies
    grants some.
  EOT
  type = object({
    name        = string
    description = optional(string, "Terragrunt runs of ovh-tf")
  })
  default = null
}

variable "iam_policies" {
  description = <<-EOT
    IAM policies granted to the OAuth2 client, by name: the URNs of the
    resources and the actions allowed on them (e.g. vps:apiovh:*). Ignored
    when oauth2_client is null.
  EOT
  type = map(object({
    resources = list(string)
    allow     = list(string)
  }))
  default = {}
}
