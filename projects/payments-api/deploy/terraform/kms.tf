data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

# One customer-managed key for this service's images, logs and secrets, with
# yearly automatic rotation (PCI DSS 3.6 / 3.7).
resource "aws_kms_key" "service" {
  description             = "${var.name}: images, logs and secrets"
  enable_key_rotation     = true
  rotation_period_in_days = 365
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "service" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.service.key_id
}

data "aws_iam_policy_document" "kms" {
  # In a key policy, "*" means "this key", not every resource. Giving the account
  # root kms:* is AWS's documented default, so access is then governed by IAM.
  #checkov:skip=CKV_AWS_109:Key policy; "*" refers only to this key
  #checkov:skip=CKV_AWS_111:Key policy; "*" refers only to this key
  #checkov:skip=CKV_AWS_356:Key policy; "*" refers only to this key
  # Account administrators manage the key through IAM policies.
  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  # CloudWatch Logs may use the key, but only for this service's log group.
  statement {
    sid       = "CloudWatchLogs"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${local.partition}:logs:${var.region}:${local.account_id}:log-group:/${var.name}/*"]
    }
  }
}
