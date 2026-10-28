# Terraform - Infrastructure as Code

## Overview

Terraform is an open-source Infrastructure as Code (IaC) tool created by HashiCorp. It lets you define cloud and on-prem infrastructure in declarative configuration files (HCL -- HashiCorp Configuration Language), which can be versioned, reviewed, and reused like application code.

**Infrastructure as Code** means you describe your desired infrastructure state in files, and Terraform figures out what API calls to make to reach that state. This replaces manual point-and-click provisioning and ad-hoc scripts with a repeatable, auditable process.

## Why Use Terraform?

| Benefit | Description |
|---|---|
| **Multi-cloud** | Single tool and language for AWS, Azure, GCP, and hundreds more providers |
| **Declarative** | Describe the desired end state; Terraform handles the how |
| **Plan before apply** | Preview every change before it touches real infrastructure |
| **State tracking** | Knows what exists, so it can update or destroy incrementally |
| **Dependency graph** | Automatically determines the order of operations |
| **Modules** | Reusable, composable building blocks for infrastructure |
| **Ecosystem** | Thousands of community and official providers and modules |
| **Drift detection** | Detect and reconcile manual changes to infrastructure |

## 2026 Suitability Analysis

### When to use
- **Multi-Cloud complexity**: Use when managing resources across different providers (AWS + Cloudflare).
- **Stateful Infrastructure**: Best for long-lived resources like VPCs, Databases, and IAM.

### Alternatives
- **OpenTofu**: Choose if your organization requires a strictly MPL-licensed open-source engine.
- **Crossplane**: Consider if you prefer managing infrastructure directly via Kubernetes CRDs (GitOps native).

## Installation

### macOS

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Or via tfenv (version manager, recommended)
brew install tfenv
tfenv install latest
tfenv use latest
```

### Linux

```bash
# Ubuntu/Debian
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Or via tfenv
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc
tfenv install latest
```

### Windows

```powershell
# Via Chocolatey
choco install terraform

# Or via Scoop
scoop install terraform
```

### Verify

```bash
terraform -version
```

## Basic Configuration

### Provider Setup

Create a `main.tf` file:

```hcl
# Terraform settings
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }
}
```

### Project Structure (Recommended)

```
project/
├── main.tf              # Primary resources
├── variables.tf         # Input variable declarations
├── outputs.tf           # Output value declarations
├── terraform.tfvars     # Variable values (do NOT commit secrets)
├── providers.tf         # Provider configuration
├── backend.tf           # State backend configuration
├── versions.tf          # Terraform and provider version constraints
├── locals.tf            # Local values
└── modules/
    └── vpc/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## HCL Basics

### Variables

```hcl
# variables.tf
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "instance_count" {
  description = "Number of EC2 instances"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "availability_zones" {
  description = "List of AZs"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
```

```hcl
# terraform.tfvars
aws_region     = "us-west-2"
environment    = "production"
instance_count = 3
```

### Resources

```hcl
# main.tf
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"
    Tier = "public"
  }
}

resource "aws_instance" "web" {
  count         = var.instance_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public[count.index % length(aws_subnet.public)].id

  tags = {
    Name = "${var.project_name}-web-${count.index + 1}"
  }
}
```

### Data Sources

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-24.04-amd64-server-*"]
  }
}

data "aws_caller_identity" "current" {}
```

### Outputs

```hcl
# outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "instance_ips" {
  description = "Public IPs of web instances"
  value       = aws_instance.web[*].public_ip
}

output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}
```

### Locals

```hcl
locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
  })

  name_prefix = "${var.project_name}-${var.environment}"
}
```

## State Management

Terraform tracks all managed infrastructure in a **state file** (`terraform.tfstate`). This file is critical and must be handled carefully.

### Remote State with S3 (Recommended for Teams)

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"  # State locking
  }
}
```

### Remote State with Azure Blob Storage

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstateaccount"
    container_name       = "tfstate"
    key                  = "production.terraform.tfstate"
  }
}
```

### State Commands

```bash
terraform state list                          # List all resources in state
terraform state show aws_instance.web[0]      # Show details of a resource
terraform state mv aws_instance.web aws_instance.app  # Rename/move resource
terraform state rm aws_instance.web[0]        # Remove resource from state (does not destroy)
terraform state pull                          # Download remote state to stdout
```

## Key Commands

```bash
# Initialize (download providers, configure backend)
terraform init

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Plan (preview changes)
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan                        # Apply a saved plan
terraform apply -auto-approve                 # Skip confirmation (CI/CD only)

# Destroy infrastructure
terraform destroy

# Show current state
terraform show

# Import existing resource into state
terraform import aws_instance.web i-0123456789abcdef0

# Refresh state against real infrastructure
terraform refresh

# Output values
terraform output
terraform output vpc_id
```

## Modules

Modules are reusable packages of Terraform configuration.

### Using a Module

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.0"

  name = "${local.name_prefix}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = var.environment != "production"

  tags = local.common_tags
}
```

### Writing a Module

```hcl
# modules/s3-bucket/variables.tf
variable "bucket_name" {
  type = string
}
variable "environment" {
  type = string
}

# modules/s3-bucket/main.tf
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags = {
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

# modules/s3-bucket/outputs.tf
output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}
```

## Workspaces

Workspaces let you manage multiple environments with the same configuration.

```bash
terraform workspace list
terraform workspace new staging
terraform workspace select staging
terraform workspace show
```

```hcl
# Use workspace name in configuration
resource "aws_instance" "web" {
  instance_type = terraform.workspace == "production" ? "t3.large" : "t3.micro"
  tags = {
    Environment = terraform.workspace
  }
}
```

> **Note:** Many teams prefer separate directories or Terragrunt over workspaces for environment separation, as workspaces share the same backend configuration.

## Best Practices

### Code Organization

1. **One resource type per file** or group related resources logically
2. **Use consistent naming** -- `resource_type.descriptive_name`
3. **Run `terraform fmt`** before every commit
4. **Use `.terraform.lock.hcl`** -- commit it to version control for reproducible provider versions

### Safety

5. **Always run `plan` before `apply`** -- review every change
6. **Use remote state with locking** -- prevents concurrent modifications
7. **Enable state encryption** -- state files contain sensitive data
8. **Never commit `terraform.tfstate` or `.tfvars` files with secrets**
9. **Use `-target` sparingly** -- it can create state drift

### Architecture

10. **Keep modules small and focused** -- one logical concern per module
11. **Pin provider and module versions** -- `~> 5.0` not `>= 5.0`
12. **Use `for_each` over `count`** when resources have meaningful identifiers
13. **Avoid hardcoding** -- use variables, data sources, and locals
14. **Tag everything** -- use `default_tags` in the provider block

### CI/CD Integration

```yaml
# Example GitHub Actions workflow
name: Terraform
on:
  pull_request:
    paths: ["infra/**"]

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init
        working-directory: infra
      - run: terraform plan -no-color
        working-directory: infra
```

## Terraform 1.x Features

- **`moved` blocks** -- Refactor resources without destroying and recreating
  ```hcl
  moved {
    from = aws_instance.web
    to   = module.compute.aws_instance.web
  }
  ```
- **`import` blocks** -- Declarative import in configuration (1.5+)
  ```hcl
  import {
    to = aws_instance.web
    id = "i-0123456789abcdef0"
  }
  ```
- **`check` blocks** -- Post-apply assertions (1.5+)
  ```hcl
  check "health" {
    data "http" "api" {
      url = "https://${aws_lb.main.dns_name}/health"
    }
    assert {
      condition     = data.http.api.status_code == 200
      error_message = "API health check failed"
    }
  }
  ```
- **`terraform test`** -- Native testing framework (1.6+)
- **Provider-defined functions** (1.8+)

## OpenTofu

[OpenTofu](https://opentofu.org/) is an open-source fork of Terraform, created after HashiCorp changed Terraform's license from MPL to BSL in August 2023. OpenTofu is maintained by the Linux Foundation and aims to remain a drop-in replacement. Key differences:

- MPL 2.0 licensed (truly open source)
- Client-side state encryption
- Early support for provider-defined functions
- Growing community and ecosystem

Migration is straightforward for most configurations: replace `terraform` with `tofu`.

## Resources

- [Official Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [Terraform Registry (Providers & Modules)](https://registry.terraform.io/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Learn Terraform (HashiCorp Tutorials)](https://developer.hashicorp.com/terraform/tutorials)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Terragrunt](https://terragrunt.gruntwork.io/) -- thin wrapper for keeping Terraform DRY
- [tflint](https://github.com/terraform-linters/tflint) -- Terraform linter
- [Checkov](https://www.checkov.io/) -- Static analysis for IaC security
