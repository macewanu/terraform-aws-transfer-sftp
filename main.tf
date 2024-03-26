locals {
  enabled     = module.this.enabled
  s3_enabled  = local.enabled && var.domain == "S3"
  efs_enabled = local.enabled && var.domain == "EFS"

  s3_arn_prefix = local.s3_enabled ? "arn:${one(data.aws_partition.default[*].partition)}:s3:::" : ""

  is_vpc = var.vpc_id != null

  user_names = keys(var.sftp_users)

  user_names_map = var.sftp_users

  user_ssh_keys_map = merge([
    for username, user_data in var.sftp_users : {
      for key_id, key in user_data.public_keys : "${username}+${key_id}" => {
        username = username
        key = key
      }
    }
  ]...)
}

data "aws_partition" "default" {}

resource "aws_transfer_server" "default" {
  count = local.enabled ? 1 : 0

  identity_provider_type = "SERVICE_MANAGED"
  protocols              = ["SFTP"]
  domain                 = var.domain
  endpoint_type          = local.is_vpc ? "VPC" : "PUBLIC"
  force_destroy          = var.force_destroy
  security_policy_name   = var.security_policy_name
  logging_role           = join("", aws_iam_role.logging[*].arn)

  structured_log_destinations = var.transfer_server_log_group_arns

  dynamic "endpoint_details" {
    for_each = local.is_vpc ? [1] : []

    content {
      subnet_ids             = var.subnet_ids
      security_group_ids     = var.vpc_security_group_ids
      vpc_id                 = var.vpc_id
      address_allocation_ids = var.eip_enabled ? aws_eip.sftp.*.id : var.address_allocation_ids
    }
  }

  tags = module.this.tags
}

resource "aws_transfer_tag" "zone_id" {
  count = local.enabled && var.route53_zone_id != null ? 1 : 0

  resource_arn = aws_transfer_server.default[0].arn
  key          = "aws:transfer:route53HostedZoneId"
  value        = "/hostedzone/${var.route53_zone_id}"
}

resource "aws_transfer_tag" "hostname" {
  count = local.enabled && var.route53_domain_name != null ? 1 : 0

  resource_arn = aws_transfer_server.default[0].arn
  key          = "aws:transfer:customHostname"
  value        = var.route53_domain_name
}

resource "aws_transfer_ssh_key" "default" {
  for_each = local.enabled ? local.user_ssh_keys_map : {}

  server_id = join("", aws_transfer_server.default[*].id)

  user_name = each.value.username
  body      = each.value.key

  depends_on = [
    aws_transfer_user.efs,
    aws_transfer_user.s3
  ]
}

resource "aws_eip" "sftp" {
  count = local.enabled && var.eip_enabled ? length(var.subnet_ids) : 0
  domain = "vpc"
  tags = module.this.tags
}

# Custom Domain
resource "aws_route53_record" "main" {
  count = local.enabled && length(var.domain_name) > 0 && length(var.zone_id) > 0 ? 1 : 0

  name    = var.domain_name
  zone_id = var.zone_id
  type    = "CNAME"
  ttl     = "300"

  records = [
    join("", aws_transfer_server.default[*].endpoint)
  ]
}

data "aws_iam_policy_document" "assume_role_policy" {
  count = local.enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com"]
    }
  }
}
