variable "display_name" {
  description = "Display name of the VPS."
  type        = string
  default     = null
}

variable "name" {
  description = "Name of the VPS (computed by OVHcloud; leave null)."
  type        = string
  default     = null
}

variable "keymap" {
  description = "KVM keyboard layout (e.g. fr, us)."
  type        = string
  default     = null
}

variable "netboot_mode" {
  description = "Netboot mode (local or rescue)."
  type        = string
  default     = null
}

variable "sla_monitoring" {
  description = "Enable OVHcloud SLA monitoring."
  type        = bool
  default     = null
}

variable "state" {
  description = "Desired state of the VPS (running, stopped, ...)."
  type        = string
  default     = null
}

variable "offer_type" {
  description = "Offer type (ssd, cloud, ...). Describes the ordered offer."
  type        = string
  default     = null
}

variable "zone" {
  description = "OpenStack region the VPS is located in. Describes the ordered offer."
  type        = string
  default     = null
}

variable "vcore" {
  description = "Number of vcores. Describes the ordered offer."
  type        = number
  default     = null
}

variable "memory_limit" {
  description = "RAM of the VPS, in MB. Describes the ordered offer."
  type        = number
  default     = null
}

variable "monitoring_ip_blocks" {
  description = "IP blocks of the OVHcloud monitoring servers."
  type        = list(string)
  default     = null
}

variable "model" {
  description = "Characteristics of the VPS model. Describes the ordered offer."
  type = object({
    available_options      = optional(list(string))
    datacenter             = optional(list(string))
    disk                   = optional(number)
    maximum_additionnal_ip = optional(number)
    memory                 = optional(number)
    name                   = optional(string)
    offer                  = optional(string)
    vcore                  = optional(number)
    version                = optional(string)
  })
  default = null
}

variable "ovh_subsidiary" {
  description = "OVHcloud subsidiary the VPS is billed by (e.g. FR). Order-time only, ignored once the VPS exists."
  type        = string
  default     = null
}

variable "image_id" {
  description = "Image to install. Setting or changing it REINSTALLS the VPS."
  type        = string
  default     = null
}

variable "public_ssh_key" {
  description = "Public SSH key pre-installed at order time (requires image_id). Ignored once the VPS exists."
  type        = string
  default     = null
}

variable "do_not_send_password" {
  description = "Do not set and mail a default password. Order-time only, ignored once the VPS exists."
  type        = bool
  default     = null
}

variable "plan" {
  description = "Order plan. Used only to order a new VPS; ignored once the VPS exists."
  type = object({
    plan_code    = string
    duration     = string
    pricing_mode = string
    configuration = optional(list(object({
      label = string
      value = string
    })))
    item_id  = optional(string)
    quantity = optional(number)
  })
  default = null
}

variable "plan_option" {
  description = "Order plan of an option. Used only at order time; ignored once the VPS exists."
  type = object({
    plan_code    = string
    duration     = string
    pricing_mode = string
    quantity     = number
    configuration = optional(list(object({
      label = string
      value = string
    })))
  })
  default = null
}

variable "reverse_dns" {
  description = <<-EOT
    Reverse DNS records, keyed by the VPS IP address (see the `ips` output).
    `reverse` is the hostname; `ip` is the IP block the address belongs to
    as a CIDR; it defaults to <address>/32 (IPv4) or <address>/128 (IPv6). The hostname must already resolve to
    the address (A/AAAA record), otherwise OVHcloud refuses the record.
  EOT
  type = map(object({
    reverse = string
    ip      = optional(string)
  }))
  default = {}
}
