output "project_id" {
  description = "Id of the Public Cloud project."
  value       = local.project_id
}

output "user_id" {
  description = "Id of the user that accesses the bucket."
  value       = ovh_cloud_project_user.this.id
}

output "access_key_id" {
  description = "S3 access key id (AWS_ACCESS_KEY_ID)."
  value       = ovh_cloud_project_user_s3_credential.this.access_key_id
}

output "secret_access_key" {
  description = "S3 secret access key (AWS_SECRET_ACCESS_KEY)."
  value       = ovh_cloud_project_user_s3_credential.this.secret_access_key
  sensitive   = true
}

output "bucket_name" {
  description = "Name of the state bucket."
  value       = ovh_cloud_storage_object_bucket.this.name
}

output "oauth2_client_id" {
  description = "Client id of the OAuth2 service account (OVH_CLIENT_ID); null when none."
  value       = one(ovh_me_api_oauth2_client.this[*].client_id)
}

output "oauth2_client_secret" {
  description = "Client secret of the OAuth2 service account (OVH_CLIENT_SECRET); null when none."
  value       = one(ovh_me_api_oauth2_client.this[*].client_secret)
  sensitive   = true
}
