output "id" {
  description = "ID of the created example"
  value       = module.this.enabled ? module.this.id : null
}

output "server_id" {
  description = "Server ID of the created transfer server"
  value       = module.this.enabled ? join("", aws_transfer_server.default.*.id) : null
}

output "transfer_endpoint" {
  description = "The endpoint of the Transfer Server"
  value       = module.this.enabled ? join("", aws_transfer_server.default.*.endpoint) : null
}

output "elastic_ips" {
  description = "Provisioned Elastic IPs"
  value       = module.this.enabled && var.eip_enabled ? aws_eip.sftp.*.id : null
}

output "s3_access_role_arns" {
  description = "Role ARNs for the S3 access"
  value       = { for user, val in aws_iam_role.s3_access_for_sftp_users : user => val.arn }
}

output "efs_access_role_arns" {
  description = "Role ARNs for the EFS access"
  value       = { for user, val in aws_iam_role.efs_access_for_sftp_users : user => val.arn }
}

output "transfer_server_endpoint_details" {
  value = module.this.enabled ? aws_transfer_server.default[0].endpoint_details : null
}
