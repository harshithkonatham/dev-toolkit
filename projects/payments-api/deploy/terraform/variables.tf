variable "name" {
  description = "Service name, used as a prefix for every resource."
  type        = string
  default     = "payments-api"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.name))
    error_message = "name must be 3-31 lowercase letters, digits or hyphens."
  }
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-2" # London
}

variable "github_repository" {
  description = "GitHub repository (owner/name) whose main branch may push images."
  type        = string
  default     = "harshithkonatham/dev-toolkit"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like owner/name."
  }
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if the account already has one."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "How long to keep application logs. PCI DSS 10.5.1 asks for at least 12 months."
  type        = number
  default     = 365

  validation {
    condition     = var.log_retention_days >= 365
    error_message = "Keep logs for at least 365 days (PCI DSS 10.5.1)."
  }
}

variable "tags" {
  description = "Extra tags added to every resource."
  type        = map(string)
  default     = {}
}
