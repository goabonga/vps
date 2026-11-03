output "id" {
  description = "Identifier of the VPS (its service name)."
  value       = ovh_vps.this.id
}

output "service_name" {
  description = "Service name of the VPS (identifier used by the OVHcloud API)."
  value       = ovh_vps.this.service_name
}

output "name" {
  description = "Name of the VPS."
  value       = ovh_vps.this.name
}

output "display_name" {
  description = "Display name of the VPS."
  value       = ovh_vps.this.display_name
}

output "cluster" {
  description = "Cluster the VPS belongs to."
  value       = ovh_vps.this.cluster
}

output "iam" {
  description = "IAM resource information (id, urn, display_name, tags)."
  value       = ovh_vps.this.iam
}

output "order" {
  description = "Order information of the VPS."
  value       = ovh_vps.this.order
}

output "keymap" {
  description = "KVM keyboard layout."
  value       = ovh_vps.this.keymap
}

output "netboot_mode" {
  description = "Netboot mode (local or rescue)."
  value       = ovh_vps.this.netboot_mode
}

output "sla_monitoring" {
  description = "Whether SLA monitoring is enabled."
  value       = ovh_vps.this.sla_monitoring
}

output "state" {
  description = "State of the VPS."
  value       = ovh_vps.this.state
}

output "offer_type" {
  description = "Offer type of the VPS."
  value       = ovh_vps.this.offer_type
}

output "zone" {
  description = "Region where the VPS is located."
  value       = ovh_vps.this.zone
}

output "vcore" {
  description = "Number of vcores of the VPS."
  value       = ovh_vps.this.vcore
}

output "memory_limit" {
  description = "RAM of the VPS, in MB."
  value       = ovh_vps.this.memory_limit
}

output "monitoring_ip_blocks" {
  description = "IP blocks of the OVHcloud monitoring servers."
  value       = ovh_vps.this.monitoring_ip_blocks
}

output "model" {
  description = "Characteristics of the VPS model."
  value       = ovh_vps.this.model
}

output "offer" {
  description = "Offer of the VPS (e.g. VPS-1 2026)."
  value       = ovh_vps.this.model.offer
}

output "ips" {
  description = "All IP addresses of the VPS (IPv4 and IPv6)."
  value       = data.ovh_vps.this.ips
}

output "ipv4" {
  description = "IPv4 addresses of the VPS."
  value       = [for ip in data.ovh_vps.this.ips : ip if !strcontains(ip, ":")]
}

output "ipv6" {
  description = "IPv6 addresses of the VPS."
  value       = [for ip in data.ovh_vps.this.ips : ip if strcontains(ip, ":")]
}

output "reverse_dns" {
  description = "Reverse DNS records managed by the module, keyed by IP address."
  value       = { for ip, r in ovh_ip_reverse.this : ip => r.reverse }
}
