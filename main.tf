locals {
  enabled     = module.this.enabled
  s3_enabled  = local.enabled && var.domain == "S3"
  efs_enabled = local.enabled && var.domain == "EFS"

  s3_arn_prefix = local.s3_enabled ? "arn:${one(data.aws_partition.default[*].partition)}:s3:::" : ""

  is_vpc = var.vpc_id != null

  user_names = keys(var.sftp_users)

  user_names_map = var.sftp_users
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

resource "aws_transfer_ssh_key" "default" {
  for_each = local.enabled ? var.sftp_users : {}

  server_id = join("", aws_transfer_server.default[*].id)

  user_name = each.value.user_name
  body      = each.value.public_key

  depends_on = [
    aws_transfer_user.efs,
    aws_transfer_user.s3
  ]
}

resource "aws_eip" "sftp" {
  count = local.enabled && var.eip_enabled ? length(var.subnet_ids) : 0

  vpc = local.is_vpc

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
