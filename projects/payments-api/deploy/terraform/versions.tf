terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # State holds resource IDs (not secret values, which are set outside Terraform).
  # Use an encrypted, versioned S3 backend with locking for real environments:
  #
  # backend "s3" {
  #   bucket       = "<state-bucket>"
  #   key          = "payments-api/terraform.tfstate"
  #   region       = "eu-west-2"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = merge(var.tags, {
      Service   = var.name
      ManagedBy = "terraform"
      DataClass = "pci-cardholder-adjacent"
    })
  }
}
