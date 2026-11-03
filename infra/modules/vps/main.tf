resource "ovh_vps" "this" {
  display_name         = var.display_name
  name                 = var.name
  keymap               = var.keymap
  netboot_mode         = var.netboot_mode
  sla_monitoring       = var.sla_monitoring
  state                = var.state
  offer_type           = var.offer_type
  zone                 = var.zone
  vcore                = var.vcore
  memory_limit         = var.memory_limit
  monitoring_ip_blocks = var.monitoring_ip_blocks
  model                = var.model

  # Order-time / reinstall arguments.
  ovh_subsidiary       = var.ovh_subsidiary
  image_id             = var.image_id
  public_ssh_key       = var.public_ssh_key
  do_not_send_password = var.do_not_send_password

  # Objects built field by field: passing `[var.plan]` directly makes the
  # provider report plan[0].* as unset ("Missing Configuration for
  # Required Attribute").
  plan = var.plan == null ? null : [{
    plan_code     = var.plan.plan_code
    duration      = var.plan.duration
    pricing_mode  = var.plan.pricing_mode
    configuration = var.plan.configuration
    item_id       = var.plan.item_id
    quantity      = var.plan.quantity
  }]

  plan_option = var.plan_option == null ? null : [{
    plan_code     = var.plan_option.plan_code
    duration      = var.plan_option.duration
    pricing_mode  = var.plan_option.pricing_mode
    configuration = var.plan_option.configuration
    quantity      = var.plan_option.quantity
  }]

  lifecycle {
    # Destroying terminates the OVHcloud service.
    prevent_destroy = true

    # Order-time arguments are not readable back from an existing VPS. An
    # imported VPS has `plan = []` in state, so without this the config
    # shows a diff and the provider marks every computed attribute as
    # "known after apply". `image_id` is deliberately NOT ignored: changing
    # it reinstalls the VPS.
    ignore_changes = [
      plan,
      plan_option,
      ovh_subsidiary,
      public_ssh_key,
      do_not_send_password,
    ]
  }
}

resource "ovh_ip_reverse" "this" {
  for_each = var.reverse_dns

  # The provider requires a CIDR block: a single address is a /32 (IPv4)
  # or a /128 (IPv6) unless `ip` says otherwise.
  ip         = coalesce(each.value.ip, "${each.key}/${strcontains(each.key, ":") ? 128 : 32}")
  ip_reverse = each.key
  # OVHcloud stores hostnames with a trailing dot; without it the config
  # never matches the state and forces a replacement.
  reverse = endswith(each.value.reverse, ".") ? each.value.reverse : "${each.value.reverse}."

  lifecycle {
    precondition {
      condition     = contains(data.ovh_vps.this.ips, each.key)
      error_message = "${each.key} is not one of the IP addresses of the VPS (${join(", ", data.ovh_vps.this.ips)})."
    }
  }
}
