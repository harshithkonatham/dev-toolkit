output "ecr_repository_url" {
  description = "Where CI pushes images."
  value       = aws_ecr_repository.api.repository_url
}

output "github_push_role_arn" {
  description = "Role for aws-actions/configure-aws-credentials in GitHub Actions."
  value       = aws_iam_role.github_push.arn
}

output "kms_key_arn" {
  description = "Customer-managed key for images, logs and secrets."
  value       = aws_kms_key.service.arn
}

output "secret_arns" {
  description = "Secrets Manager ARNs; set their values outside Terraform."
  value       = { for k, s in aws_secretsmanager_secret.service : k => s.arn }
}

output "log_groups" {
  description = "CloudWatch log groups."
  value       = [aws_cloudwatch_log_group.api.name, aws_cloudwatch_log_group.risk_monitor.name]
}
