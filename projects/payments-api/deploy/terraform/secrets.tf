# Secret containers only. Values are written outside Terraform (for example
# `aws secretsmanager put-secret-value`), so they never appear in code or state.
locals {
  secrets = {
    jwt-secret   = "HS256 signing key for access tokens"
    pan-hmac-key = "HMAC key for card fingerprints"
    rabbitmq-url = "amqps:// URL, including credentials, for the event broker"
  }
}

resource "aws_secretsmanager_secret" "service" {
  # Rotation is manual (README.md, "Secret rotation"): rotating the PAN HMAC
  # key needs a re-fingerprinting step, and JWT keys need an overlap window.
  #checkov:skip=CKV2_AWS_57:Rotation is a documented manual procedure (see README.md)
  for_each = local.secrets

  name                    = "${var.name}/${each.key}"
  description             = each.value
  kms_key_id              = aws_kms_key.service.arn
  recovery_window_in_days = 30
}
