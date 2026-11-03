# --- Public Cloud project (optional order) -------------------------------

data "ovh_me" "this" {
  count = var.order_project == null ? 0 : 1
}

data "ovh_order_cart" "this" {
  count = var.order_project == null ? 0 : 1

  ovh_subsidiary = coalesce(var.order_project.ovh_subsidiary, data.ovh_me.this[0].ovh_subsidiary)
}

data "ovh_order_cart_product_plan" "this" {
  count = var.order_project == null ? 0 : 1

  cart_id        = data.ovh_order_cart.this[0].id
  price_capacity = "renew"
  product        = "cloud"
  plan_code      = var.order_project.plan_code
}

resource "ovh_cloud_project" "this" {
  count = var.order_project == null ? 0 : 1

  ovh_subsidiary = data.ovh_order_cart.this[0].ovh_subsidiary
  description    = var.order_project.description

  plan {
    duration     = data.ovh_order_cart_product_plan.this[0].selected_price[0].duration
    plan_code    = data.ovh_order_cart_product_plan.this[0].plan_code
    pricing_mode = data.ovh_order_cart_product_plan.this[0].selected_price[0].pricing_mode
  }

  lifecycle {
    # Destroying terminates the project, and everything in it.
    prevent_destroy = true
  }
}

locals {
  project_id = var.order_project == null ? var.project_id : ovh_cloud_project.this[0].project_id
}

# --- OAuth2 service account for the day-to-day runs ------------------------

data "ovh_me" "account" {
  count = var.oauth2_client == null ? 0 : 1
}

resource "ovh_me_api_oauth2_client" "this" {
  count = var.oauth2_client == null ? 0 : 1

  name        = var.oauth2_client.name
  description = var.oauth2_client.description
  flow        = "CLIENT_CREDENTIALS"
}

# Lets the provider read the account when it initializes.
resource "ovh_iam_policy" "account" {
  count = var.oauth2_client == null ? 0 : 1

  # OVHcloud reserves the "ovh-" prefix for policy names.
  name        = "tf-${var.oauth2_client.name}-account"
  description = "Read access to the account for ${var.oauth2_client.name}"
  identities  = [ovh_me_api_oauth2_client.this[0].identity]
  resources   = [data.ovh_me.account[0].urn]
  allow       = ["account:apiovh:me/get"]
}

resource "ovh_iam_policy" "this" {
  for_each = var.oauth2_client == null ? {} : var.iam_policies

  # OVHcloud reserves the "ovh-" prefix for policy names.
  name        = "tf-${var.oauth2_client.name}-${each.key}"
  description = "${each.key} access for ${var.oauth2_client.name}"
  identities  = [ovh_me_api_oauth2_client.this[0].identity]
  resources   = each.value.resources
  allow       = each.value.allow
}

# --- user, S3 credentials and policy -------------------------------------

resource "ovh_cloud_project_user" "this" {
  service_name = local.project_id
  description  = var.user_description
  role_names   = ["objectstore_operator"]

  lifecycle {
    precondition {
      condition     = (var.project_id == null) != (var.order_project == null)
      error_message = "Set exactly one of project_id (existing project) and order_project (new project)."
    }
  }
}

resource "ovh_cloud_project_user_s3_credential" "this" {
  service_name = local.project_id
  user_id      = ovh_cloud_project_user.this.id
}

# Without a policy the user gets AccessDenied on every bucket.
resource "ovh_cloud_project_user_s3_policy" "this" {
  service_name = local.project_id
  user_id      = ovh_cloud_project_user.this.id

  policy = jsonencode({
    Statement = [{
      Sid    = "tfstate"
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:ListBucketMultipartUploads",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload",
      ]
      Resource = [
        "arn:aws:s3:::${var.bucket_name}",
        "arn:aws:s3:::${var.bucket_name}/*",
      ]
    }]
  })
}

# --- state bucket ---------------------------------------------------------

resource "ovh_cloud_storage_object_bucket" "this" {
  service_name = local.project_id
  name         = var.bucket_name
  region       = upper(var.bucket_region)

  versioning = {
    status = var.bucket_versioning ? "ENABLED" : "DISABLED"
  }

  encryption = {
    algorithm = var.bucket_encryption
  }

  tags = var.bucket_tags

  lifecycle {
    # The bucket holds the Terraform states.
    prevent_destroy = true

    # Object lock can only be armed at creation. An imported bucket reports
    # an empty object_lock, and its absence from the config would otherwise
    # force a replacement.
    ignore_changes = [object_lock]
  }
}

# --- retention of the stored plans -------------------------------------------

# The plan workflows store the full plan of each run under plans/
# (plans/<pipeline>-<env>/<run id>/plan.txt). Only that prefix is concerned: the states are
# stored under <env>/. The bucket is versioned, so an expired plan first gets a
# delete marker and its version goes one day later. The marker itself stays (it
# weighs nothing): the API refuses a rule removing delete markers that has a
# prefix filter, and such a rule without a filter would concern the states.
resource "ovh_cloud_project_storage_object_bucket_lifecycle_configuration" "plans" {
  count = var.plans_retention_days == null ? 0 : 1

  service_name   = local.project_id
  container_name = ovh_cloud_storage_object_bucket.this.name
  region_name    = upper(var.bucket_region)

  rules = [
    {
      id     = "expire-plans"
      status = "enabled"
      filter = {
        prefix = "plans/"
      }
      expiration = {
        days = var.plans_retention_days
      }
      noncurrent_version_expiration = {
        noncurrent_days = 1
      }
      abort_incomplete_multipart_upload = {
        days_after_initiation = 1
      }
    },
  ]
}
