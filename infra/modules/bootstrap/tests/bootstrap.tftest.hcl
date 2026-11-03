# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline tests (`tofu test`): the provider is mocked, no OVHcloud
# credential or network access is needed.

mock_provider "ovh" {}

variables {
  project_id    = "0123456789abcdef0123456789abcdef"
  bucket_name   = "test-tfstate"
  bucket_region = "gra"
}

run "expires_the_plans_after_seven_days_by_default" {
  command = plan

  assert {
    condition     = length(ovh_cloud_project_storage_object_bucket_lifecycle_configuration.plans) == 1
    error_message = "a lifecycle configuration is expected by default"
  }

  assert {
    condition     = ovh_cloud_project_storage_object_bucket_lifecycle_configuration.plans[0].rules[0].expiration.days == 7
    error_message = "the plans must expire after seven days by default"
  }
}

run "only_the_plans_are_concerned" {
  command = plan

  assert {
    condition = alltrue([
      for rule in ovh_cloud_project_storage_object_bucket_lifecycle_configuration.plans[0].rules :
      rule.filter.prefix == "plans/"
    ])
    error_message = "every rule must be limited to the plans/ prefix, never the states"
  }
}

run "no_rule_without_a_prefix" {
  command = plan

  assert {
    condition = alltrue([
      for rule in ovh_cloud_project_storage_object_bucket_lifecycle_configuration.plans[0].rules :
      rule.filter != null
    ])
    error_message = "a rule without a filter would concern the states"
  }
}

run "the_retention_is_configurable" {
  command = plan

  variables {
    plans_retention_days = 30
  }

  assert {
    condition     = ovh_cloud_project_storage_object_bucket_lifecycle_configuration.plans[0].rules[0].expiration.days == 30
    error_message = "the retention must follow plans_retention_days"
  }
}

run "null_keeps_the_plans_forever" {
  command = plan

  variables {
    plans_retention_days = null
  }

  assert {
    condition     = length(ovh_cloud_project_storage_object_bucket_lifecycle_configuration.plans) == 0
    error_message = "no lifecycle configuration is expected when the retention is null"
  }
}

run "rejects_a_retention_below_one_day" {
  command = plan

  variables {
    plans_retention_days = 0
  }

  expect_failures = [var.plans_retention_days]
}
