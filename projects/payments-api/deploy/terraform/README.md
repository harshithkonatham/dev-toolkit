# AWS infrastructure (Terraform)

Creates the AWS resources the payments API needs around the cluster. This is
the security baseline only; it deploys no compute.

| Resource | Why | Controls |
|---|---|---|
| KMS key `alias/payments-api` | One customer-managed key for images, logs and secrets | Yearly automatic rotation, 30-day deletion window. CloudWatch Logs may use it only for this service's log groups. |
| ECR repository | Container images | Immutable tags, scan on push, KMS-encrypted, lifecycle cleanup |
| CloudWatch log groups | API and risk-monitor logs | KMS-encrypted, kept 365 days (PCI DSS 10.5.1; enforced by variable validation). A metric filter counts risk alerts. |
| Secrets Manager secrets | JWT key, PAN HMAC key, broker URL | KMS-encrypted. **Values are never in Terraform code or state.** |
| GitHub OIDC role | CI pushes images without stored AWS keys | Only `main` of one repo can assume it, and it can only push to this one ECR repo |

## Use

```bash
terraform init
terraform plan -out tfplan
terraform apply tfplan

# Set secret values outside Terraform:
aws secretsmanager put-secret-value --secret-id payments-api/jwt-secret \
  --secret-string "$(openssl rand -hex 32)"
```

Variables are in [`variables.tf`](variables.tf). Use an encrypted S3 backend with
locking for shared state (the template is in [`versions.tf`](versions.tf)).

## Secret rotation

Checkov's automatic-rotation check (CKV2_AWS_57) is deliberately skipped,
because each secret needs a different procedure:

| Secret | Procedure |
|---|---|
| `jwt-secret` | Tokens live 15 minutes. Write the new value, restart pods, and old tokens expire within 15 minutes. |
| `pan-hmac-key` | Changing it changes every card fingerprint. Write the new key with a version label, re-fingerprint stored rows in a migration job, then switch. |
| `rabbitmq-url` | Create a new broker user, write the new URL, restart the API and consumer, then delete the old user. |

## CI

The `iac` job in [`payments-api.yml`](../../../../.github/workflows/payments-api.yml)
runs `terraform fmt -check`, `terraform validate` and Checkov on every push.
It never runs `plan` or `apply`, so CI has no AWS credentials.
