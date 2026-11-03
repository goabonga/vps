# The ovh_vps resource does not expose the IP addresses; the data source does.
data "ovh_vps" "this" {
  service_name = ovh_vps.this.service_name
}
