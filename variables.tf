# General variables

variable "domain" {
  type        = string
  description = "Where your files are stored. S3 or EFS"
  default     = "S3"

  validation {
    condition     = contains(["EFS", "S3"], var.domain)
    error_message = "Allowed values for domain are \"EFS\" or \"S3\"."
  }
}

variable "iam_policies" {
  type = map(object({
    statements = map(object({
      efs_arn   = optional(string)
      s3_arn    = optional(string)
      actions   = list(string)
      resources = list(string)
    })) 
  }))
  default     = {}
  description = "IAM policies to create that will be used by `sftp_users`."
}

variable "sftp_users" {
  type = map(object({
    user_name  = string
    public_keys = optional(map(string), {})
    posix_profile = optional(object({
      gid            = number
      uid            = number
      secondary_gids = optional(list(number))
    }))
    home_directory = optional(object({
      create_iam_policy = optional(bool)
      efs_arn           = optional(string)
      efs_id            = optional(string)
      readonly          = optional(bool)
      s3_arn            = optional(string)
      s3_id             = optional(string)
      path              = optional(string)
      restricted        = optional(bool)
    }))
    iam_policies = optional(list(string), [])
  }))
  default     = {}
  description = "Configuration for SFTP users."
}

variable "force_destroy" {
  type        = bool
  description = "Forces the AWS Transfer Server to be destroyed"
  default     = false
}

variable "security_policy_name" {
  type        = string
  description = <<EOF
Specifies the name of the security policy that is attached to the server.

Possible values are `TransferSecurityPolicy-2022-03`, `TransferSecurityPolicy-2020-06`,
`TransferSecurityPolicy-2018-11`, and `TransferSecurityPolicy-FIPS-2020-06`. It is
recommended to use the most recent policy to only allow modern, secure cryptographic
algorithms.

If not specified, the default value is `TransferSecurityPolicy-2022-03`.
EOF
  default     = "TransferSecurityPolicy-2022-03"

  validation {
    condition = contains(
      [
        "TransferSecurityPolicy-2018-11",
        "TransferSecurityPolicy-2020-06",
        "TransferSecurityPolicy-2022-03",
        "TransferSecurityPolicy-FIPS-2020-06"
      ],
      var.security_policy_name
    )
    error_message = <<EOF
Allowed values for domain are "TransferSecurityPolicy-2018-11",
"TransferSecurityPolicy-2020-06", "TransferSecurityPolicy-2022-03", or
"TransferSecurityPolicy-FIPS-2020-06".
EOF
  }
}

variable "domain_name" {
  type        = string
  description = "Domain to use when connecting to the SFTP endpoint"
  default     = ""
}

variable "zone_id" {
  type        = string
  description = "Route53 Zone ID to add the CNAME"
  default     = ""
}

variable "eip_enabled" {
  type        = bool
  description = "Whether to provision and attach an Elastic IP to be used as the SFTP endpoint. An EIP will be provisioned per subnet."
  default     = false
}

# VPC endpoint variables.

variable "vpc_id" {
  type        = string
  description = "VPC ID that the AWS Transfer Server will be deployed to"
  default     = null
}

variable "address_allocation_ids" {
  type        = list(string)
  description = <<EOF
A list of address allocation IDs that are required to attach an Elastic IP
address to your SFTP server's endpoint.

This property is only used when `vpc_id` is provided.
EOF
  default     = []
}

variable "vpc_security_group_ids" {
  type        = list(string)
  description = <<EOF
A list of security groups IDs that are available to attach to your server's
endpoint. If no security groups are specified, the VPC's default security groups
are automatically assigned to your endpoint.

This property is only used when `vpc_id` is provided.
EOF
  default     = []
}

variable "subnet_ids" {
  type        = list(string)
  description = <<EOF
A list of subnet IDs that are required to host your SFTP server endpoint in your
VPC.

This property is only used when `vpc_id` is provided.
EOF
  default     = []
}
