# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline tests (`tofu test`): the provider is mocked, no OVHcloud
# credential or network access is needed.

mock_provider "ovh" {
  mock_data "ovh_vps" {
    defaults = {
      ips = ["192.0.2.10", "2001:db8::10"]
    }
  }
}

variables {
  display_name = "vps-test"
  netboot_mode = "local"
  state        = "running"
}

run "manages_the_vps" {
  command = plan

  assert {
    condition     = ovh_vps.this.display_name == "vps-test"
    error_message = "the display name must be passed to the VPS"
  }

  assert {
    condition     = ovh_vps.this.netboot_mode == "local"
    error_message = "the netboot mode must be passed to the VPS"
  }
}

run "no_reverse_dns_by_default" {
  command = plan

  assert {
    condition     = length(ovh_ip_reverse.this) == 0
    error_message = "no reverse DNS record is created unless asked"
  }
}

run "reverse_dns_gets_a_cidr_and_a_trailing_dot" {
  command = plan

  variables {
    reverse_dns = {
      "192.0.2.10" = { reverse = "example.org" }
    }
  }

  assert {
    condition     = ovh_ip_reverse.this["192.0.2.10"].ip == "192.0.2.10/32"
    error_message = "an IPv4 address must become a /32 block"
  }

  assert {
    condition     = ovh_ip_reverse.this["192.0.2.10"].reverse == "example.org."
    error_message = "the hostname must end with a dot"
  }
}

run "reverse_dns_of_an_ipv6_address_gets_a_128_block" {
  command = plan

  variables {
    reverse_dns = {
      "2001:db8::10" = { reverse = "example.org" }
    }
  }

  assert {
    condition     = ovh_ip_reverse.this["2001:db8::10"].ip == "2001:db8::10/128"
    error_message = "an IPv6 address must become a /128 block"
  }

  assert {
    condition     = ovh_ip_reverse.this["2001:db8::10"].reverse == "example.org."
    error_message = "the hostname must end with a dot"
  }
}

run "reverse_dns_rejects_a_foreign_address" {
  # The addresses come from the data source, only known once applied.
  command = apply

  variables {
    reverse_dns = {
      "198.51.100.1" = { reverse = "example.org" }
    }
  }

  expect_failures = [ovh_ip_reverse.this]
}
