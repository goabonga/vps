# vps
| version 0.0.0

Manages an existing OVHcloud VPS (`ovh_vps`) and the reverse DNS records of its
addresses (`ovh_ip_reverse`). Import the VPS before the first plan, see
[infra/README.md](../../README.md#importing-the-existing-vps).

The VPS is protected with `prevent_destroy`: destroying the resource would
terminate the OVHcloud service.

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
| [ovh_ip_reverse.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/ip_reverse) | resource |
| [ovh_vps.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/vps) | resource |
| [ovh_vps.this](https://registry.terraform.io/providers/ovh/ovh/latest/docs/data-sources/vps) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | Display name of the VPS. | `string` | `null` | no |
| <a name="input_do_not_send_password"></a> [do\_not\_send\_password](#input\_do\_not\_send\_password) | Do not set and mail a default password. Order-time only, ignored once the VPS exists. | `bool` | `null` | no |
| <a name="input_image_id"></a> [image\_id](#input\_image\_id) | Image to install. Setting or changing it REINSTALLS the VPS. | `string` | `null` | no |
| <a name="input_keymap"></a> [keymap](#input\_keymap) | KVM keyboard layout (e.g. fr, us). | `string` | `null` | no |
| <a name="input_memory_limit"></a> [memory\_limit](#input\_memory\_limit) | RAM of the VPS, in MB. Describes the ordered offer. | `number` | `null` | no |
| <a name="input_model"></a> [model](#input\_model) | Characteristics of the VPS model. Describes the ordered offer. | <pre>object({<br/>    available_options      = optional(list(string))<br/>    datacenter             = optional(list(string))<br/>    disk                   = optional(number)<br/>    maximum_additionnal_ip = optional(number)<br/>    memory                 = optional(number)<br/>    name                   = optional(string)<br/>    offer                  = optional(string)<br/>    vcore                  = optional(number)<br/>    version                = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_monitoring_ip_blocks"></a> [monitoring\_ip\_blocks](#input\_monitoring\_ip\_blocks) | IP blocks of the OVHcloud monitoring servers. | `list(string)` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the VPS (computed by OVHcloud; leave null). | `string` | `null` | no |
| <a name="input_netboot_mode"></a> [netboot\_mode](#input\_netboot\_mode) | Netboot mode (local or rescue). | `string` | `null` | no |
| <a name="input_offer_type"></a> [offer\_type](#input\_offer\_type) | Offer type (ssd, cloud, ...). Describes the ordered offer. | `string` | `null` | no |
| <a name="input_ovh_subsidiary"></a> [ovh\_subsidiary](#input\_ovh\_subsidiary) | OVHcloud subsidiary the VPS is billed by (e.g. FR). Order-time only, ignored once the VPS exists. | `string` | `null` | no |
| <a name="input_plan"></a> [plan](#input\_plan) | Order plan. Used only to order a new VPS; ignored once the VPS exists. | <pre>object({<br/>    plan_code    = string<br/>    duration     = string<br/>    pricing_mode = string<br/>    configuration = optional(list(object({<br/>      label = string<br/>      value = string<br/>    })))<br/>    item_id  = optional(string)<br/>    quantity = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_plan_option"></a> [plan\_option](#input\_plan\_option) | Order plan of an option. Used only at order time; ignored once the VPS exists. | <pre>object({<br/>    plan_code    = string<br/>    duration     = string<br/>    pricing_mode = string<br/>    quantity     = number<br/>    configuration = optional(list(object({<br/>      label = string<br/>      value = string<br/>    })))<br/>  })</pre> | `null` | no |
| <a name="input_public_ssh_key"></a> [public\_ssh\_key](#input\_public\_ssh\_key) | Public SSH key pre-installed at order time (requires image\_id). Ignored once the VPS exists. | `string` | `null` | no |
| <a name="input_reverse_dns"></a> [reverse\_dns](#input\_reverse\_dns) | Reverse DNS records, keyed by the VPS IP address (see the `ips` output).<br/>`reverse` is the hostname; `ip` is the IP block the address belongs to<br/>as a CIDR; it defaults to <address>/32 (IPv4) or <address>/128 (IPv6). The hostname must already resolve to<br/>the address (A/AAAA record), otherwise OVHcloud refuses the record. | <pre>map(object({<br/>    reverse = string<br/>    ip      = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_sla_monitoring"></a> [sla\_monitoring](#input\_sla\_monitoring) | Enable OVHcloud SLA monitoring. | `bool` | `null` | no |
| <a name="input_state"></a> [state](#input\_state) | Desired state of the VPS (running, stopped, ...). | `string` | `null` | no |
| <a name="input_vcore"></a> [vcore](#input\_vcore) | Number of vcores. Describes the ordered offer. | `number` | `null` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | OpenStack region the VPS is located in. Describes the ordered offer. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster"></a> [cluster](#output\_cluster) | Cluster the VPS belongs to. |
| <a name="output_display_name"></a> [display\_name](#output\_display\_name) | Display name of the VPS. |
| <a name="output_iam"></a> [iam](#output\_iam) | IAM resource information (id, urn, display\_name, tags). |
| <a name="output_id"></a> [id](#output\_id) | Identifier of the VPS (its service name). |
| <a name="output_ips"></a> [ips](#output\_ips) | All IP addresses of the VPS (IPv4 and IPv6). |
| <a name="output_ipv4"></a> [ipv4](#output\_ipv4) | IPv4 addresses of the VPS. |
| <a name="output_ipv6"></a> [ipv6](#output\_ipv6) | IPv6 addresses of the VPS. |
| <a name="output_keymap"></a> [keymap](#output\_keymap) | KVM keyboard layout. |
| <a name="output_memory_limit"></a> [memory\_limit](#output\_memory\_limit) | RAM of the VPS, in MB. |
| <a name="output_model"></a> [model](#output\_model) | Characteristics of the VPS model. |
| <a name="output_monitoring_ip_blocks"></a> [monitoring\_ip\_blocks](#output\_monitoring\_ip\_blocks) | IP blocks of the OVHcloud monitoring servers. |
| <a name="output_name"></a> [name](#output\_name) | Name of the VPS. |
| <a name="output_netboot_mode"></a> [netboot\_mode](#output\_netboot\_mode) | Netboot mode (local or rescue). |
| <a name="output_offer"></a> [offer](#output\_offer) | Offer of the VPS (e.g. VPS-1 2026). |
| <a name="output_offer_type"></a> [offer\_type](#output\_offer\_type) | Offer type of the VPS. |
| <a name="output_order"></a> [order](#output\_order) | Order information of the VPS. |
| <a name="output_reverse_dns"></a> [reverse\_dns](#output\_reverse\_dns) | Reverse DNS records managed by the module, keyed by IP address. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Service name of the VPS (identifier used by the OVHcloud API). |
| <a name="output_sla_monitoring"></a> [sla\_monitoring](#output\_sla\_monitoring) | Whether SLA monitoring is enabled. |
| <a name="output_state"></a> [state](#output\_state) | State of the VPS. |
| <a name="output_vcore"></a> [vcore](#output\_vcore) | Number of vcores of the VPS. |
| <a name="output_zone"></a> [zone](#output\_zone) | Region where the VPS is located. |
<!-- END_TF_DOCS -->
