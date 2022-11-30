# This file defines resources created when the specified domain is 'EFS'.

resource "aws_transfer_user" "efs" {
  for_each = local.enabled && var.domain == "EFS" ? var.sftp_users : {}

  # -- Required

  server_id = join("", aws_transfer_server.default[*].id)
  user_name = each.value.user_name
  role      = aws_iam_role.efs_access_for_sftp_users[each.value.user_name].arn

  # -- Optional

  # If at least some home directory configuration was provided, default to /home/${user_name} if
  # no path was given; otherwise, do not specify anything.
  home_directory = try(
    format(
      "/%s%s",
      each.value.home_directory.efs_id,
      try(
        each.value.home_directory.path,
        format("/home/%s", each.value.user_name)
      )
    ),
    null
  )

  # Control whether or not the user should be restricted to their home directory. Only applies if
  # `home_directory.restricted` is true.
  dynamic "home_directory_mappings" {
    for_each = try(each.value.home_directory.restricted ? ["true"] : [], [])

    content {
      entry = "/"
      target = format(
        "/%s%s",
        each.value.home_directory.efs_id,
        try(
          each.value.home_directory.path != null ? each.value.home_directory.path : format("/home/%s", each.value.user_name),
          format("/home/%s", each.value.user_name)
        )
      )
    }
  }

  # LOGICAL type only used when `home_directory.restricted` is true.
  home_directory_type = try(each.value.home_directory.restricted ? "LOGICAL" : "PATH", "PATH")

  # Full POSIX identity for the user.
  posix_profile {
    gid            = try(each.value.posix_profile.gid, 65534)
    uid            = try(each.value.posix_profile.uid, 65534)
    secondary_gids = try(each.value.posix_profile.secondary_gids, [])
  }

  tags = module.this.tags
}


data "aws_iam_policy_document" "efs_access_for_sftp_users" {
  for_each = local.efs_enabled ? local.user_names_map : {}

  dynamic "statement" {
    for_each = (
      try(each.value.home_directory != null ? true : false) ? (
        try(each.value.home_directory.create_iam_policy == null || each.value.home_directory.create_iam_policy, true) ? ["true"] : []
      ) : []
    )

    content {
      sid    = "TransferUserHomeDirectoryPermissions"
      effect = "Allow"

      actions = [
        "elasticfilesystem:ClientMount",
        try(each.value.home_directory.readonly != null ? each.value.home_directory.readonly : false) ? "" : "elasticfilesystem:ClientWrite"
      ]

      resources = [
        format(
          "%s%s/*",
          each.value.home_directory.efs_arn,
          try(
            each.value.home_directory.path != null ? each.value.home_directory.path : format("/home/%s", each.value.user_name),
            format("/home/%s", each.value.user_name)
          )
        )
      ]
    }
  }

  # For each additional iam_statement provided, create a corresponding statement in the
  # policy document.
  dynamic "statement" {
    for_each = each.value.iam_statements != null ? each.value.iam_statements : {}

    content {
      sid     = statement.key
      effect  = "Allow"
      actions = statement.value.actions

      resources = [
        for resource in statement.value.resources :
        format("%s%s", statement.value.efs_arn, resource)
      ]
    }
  }
}

module "efs_iam_label" {
  for_each = local.efs_enabled ? local.user_names_map : {}

  source  = "cloudposse/label/null"
  version = "0.25.0"

  attributes = ["transfer", "efs", each.value.user_name]

  context = module.this.context
}

resource "aws_iam_policy" "efs_access_for_sftp_users" {
  for_each = local.efs_enabled ? local.user_names_map : {}

  name   = module.efs_iam_label[each.value.user_name].id
  policy = data.aws_iam_policy_document.efs_access_for_sftp_users[each.value.user_name].json

  tags = module.this.tags
}

resource "aws_iam_role" "efs_access_for_sftp_users" {
  for_each = local.efs_enabled ? local.user_names_map : {}

  name = module.efs_iam_label[each.value.user_name].id

  assume_role_policy  = join("", data.aws_iam_policy_document.assume_role_policy[*].json)
  managed_policy_arns = [aws_iam_policy.efs_access_for_sftp_users[each.value.user_name].arn]

  tags = module.this.tags
}
