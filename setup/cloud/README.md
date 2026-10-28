# Cloud CLI Tools — AWS, GCP, Azure, Terraform

Setup and command reference for major cloud CLIs.
Updated: April 2026.

---

## AWS CLI v2

### Install & Configure

```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

aws --version

# Initial setup
aws configure
# AWS Access Key ID: AKIA...
# AWS Secret Access Key: ...
# Default region name: us-east-1
# Default output format: json   (or table, text, yaml)
```

### Profiles

```bash
# Add named profile
aws configure --profile prod
aws configure --profile staging

# Use profile
aws s3 ls --profile prod
export AWS_PROFILE=prod           # set for current session

# List profiles
aws configure list-profiles

# Check current identity
aws sts get-caller-identity
```

### EC2

```bash
# List instances
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Start/stop
aws ec2 start-instances --instance-ids i-1234567890abcdef0
aws ec2 stop-instances --instance-ids i-1234567890abcdef0

# Get instance public IP
aws ec2 describe-instances \
  --instance-ids i-1234567890abcdef0 \
  --query 'Reservations[0].Instances[0].PublicIpAddress'

# List security groups
aws ec2 describe-security-groups --output table

# Key pairs
aws ec2 describe-key-pairs --output table
```

### S3

```bash
# List buckets
aws s3 ls

# List objects in bucket
aws s3 ls s3://my-bucket/
aws s3 ls s3://my-bucket/prefix/ --recursive

# Upload
aws s3 cp ./file.txt s3://my-bucket/
aws s3 sync ./local-dir s3://my-bucket/prefix/

# Download
aws s3 cp s3://my-bucket/file.txt ./file.txt
aws s3 sync s3://my-bucket/ ./local-dir/

# Move / delete
aws s3 mv s3://my-bucket/old.txt s3://my-bucket/new.txt
aws s3 rm s3://my-bucket/file.txt
aws s3 rm s3://my-bucket/prefix/ --recursive

# Presigned URL
aws s3 presign s3://my-bucket/file.txt --expires-in 3600

# Bucket operations
aws s3 mb s3://my-new-bucket
aws s3 rb s3://my-empty-bucket
```

### ECS / ECR

```bash
# ECR login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.us-east-1.amazonaws.com

# Push image to ECR
docker tag myapp:latest 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:latest
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:latest

# ECS
aws ecs list-clusters
aws ecs list-services --cluster my-cluster
aws ecs describe-services --cluster my-cluster --services my-service

# Force new deployment
aws ecs update-service \
  --cluster my-cluster \
  --service my-service \
  --force-new-deployment
```

### Lambda

```bash
# List functions
aws lambda list-functions --query 'Functions[*].[FunctionName,Runtime,LastModified]' --output table

# Invoke
aws lambda invoke \
  --function-name my-function \
  --payload '{"key":"value"}' \
  response.json

# Deploy code
aws lambda update-function-code \
  --function-name my-function \
  --zip-file fileb://function.zip
```

### RDS

```bash
aws rds describe-db-instances \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address]' \
  --output table

# Start/stop DB instance
aws rds start-db-instance --db-instance-identifier mydb
aws rds stop-db-instance --db-instance-identifier mydb
```

### SSM Parameter Store (secrets)

```bash
# Store
aws ssm put-parameter \
  --name "/myapp/prod/DATABASE_URL" \
  --value "postgresql://..." \
  --type SecureString

# Retrieve
aws ssm get-parameter \
  --name "/myapp/prod/DATABASE_URL" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text

# List parameters
aws ssm get-parameters-by-path \
  --path "/myapp/prod/" \
  --with-decryption
```

### Useful AWS aliases

```bash
# In ~/.zsh_aliases
alias awsid='aws sts get-caller-identity'
alias awsregion='aws configure get region'
alias awsprofile='echo $AWS_PROFILE'
alias awslogin='aws sso login'
alias ecrlogs='aws logs tail /aws/lambda/'
```

---

## Google Cloud SDK (gcloud)

### Install & Configure

```bash
# macOS
brew install --cask google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

gcloud --version

# Init (login + project)
gcloud init

# Login
gcloud auth login
gcloud auth application-default login   # for SDKs/APIs

# Set project
gcloud config set project my-project-id
export GOOGLE_CLOUD_PROJECT=my-project-id
```

### Manage configurations

```bash
# Create config profiles
gcloud config configurations create dev
gcloud config configurations create prod

# Set properties per config
gcloud config set project my-dev-project
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a

# Switch configs
gcloud config configurations activate prod
gcloud config configurations list
```

### Core commands

```bash
# Compute Engine
gcloud compute instances list
gcloud compute instances start my-vm
gcloud compute instances stop my-vm
gcloud compute ssh my-vm                # SSH into instance

# GKE
gcloud container clusters list
gcloud container clusters get-credentials my-cluster --zone us-central1-a
kubectl get pods                        # now connected to GKE

# Cloud Run
gcloud run services list
gcloud run deploy my-service \
  --image gcr.io/my-project/my-image:latest \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated

gcloud run services describe my-service --region us-central1

# Cloud Storage
gsutil ls
gsutil ls gs://my-bucket/
gsutil cp ./file.txt gs://my-bucket/
gsutil rsync -r ./local gs://my-bucket/prefix

# Artifact Registry (container images)
gcloud auth configure-docker us-central1-docker.pkg.dev
docker tag myapp us-central1-docker.pkg.dev/my-project/my-repo/myapp:latest
docker push us-central1-docker.pkg.dev/my-project/my-repo/myapp:latest

# Cloud SQL
gcloud sql instances list
gcloud sql connect my-instance --user=root

# Logs
gcloud logging read "resource.type=cloud_run_revision" --limit=50
gcloud logging tail "resource.type=cloud_run_revision"

# BigQuery
bq ls
bq query 'SELECT count(*) FROM `project.dataset.table`'
```

---

## Azure CLI

### Install & Configure

```bash
# macOS
brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

az --version

# Login
az login
az login --use-device-code          # for headless envs

# Set subscription
az account list --output table
az account set --subscription "My Subscription"
az account show
```

### Core commands

```bash
# Resource groups
az group list --output table
az group create --name mygroup --location eastus
az group delete --name mygroup

# Virtual Machines
az vm list --output table
az vm start --resource-group mygroup --name myvm
az vm stop --resource-group mygroup --name myvm
az vm ssh --resource-group mygroup --name myvm

# Azure Container Registry (ACR)
az acr list --output table
az acr login --name myregistry
docker tag myapp myregistry.azurecr.io/myapp:latest
docker push myregistry.azurecr.io/myapp:latest

# Azure Kubernetes Service (AKS)
az aks list --output table
az aks get-credentials --resource-group mygroup --name myaks
kubectl get nodes

# App Service
az webapp list --output table
az webapp deploy --resource-group mygroup --name myapp --src-path ./dist.zip

# Azure Functions
az functionapp list --output table

# Storage
az storage account list --output table
az storage blob upload --account-name mystorage --container mycontainer --file ./file.txt --name file.txt

# Key Vault (secrets)
az keyvault list --output table
az keyvault secret set --vault-name mykeyvault --name MySecret --value "myvalue"
az keyvault secret show --vault-name mykeyvault --name MySecret --query value -o tsv

# Logs
az monitor activity-log list --output table
```

---

## Terraform

### Install

```bash
brew install terraform             # macOS
brew install terragrunt            # DRY wrapper
brew install tfsec                 # security scanner
brew install infracost             # cost estimation

# or via tfenv (manage multiple versions)
brew install tfenv
tfenv install 1.10.0
tfenv use 1.10.0

terraform --version
```

### Core commands

```bash
# Initialize (download providers)
terraform init
terraform init -upgrade           # upgrade providers

# Plan (preview changes)
terraform plan
terraform plan -out=tfplan        # save plan to file

# Apply
terraform apply
terraform apply tfplan            # apply saved plan
terraform apply -auto-approve     # skip confirmation (CI)

# Destroy
terraform destroy
terraform destroy -target aws_instance.web

# State management
terraform state list              # list resources in state
terraform state show aws_s3_bucket.main
terraform state mv old_name new_name
terraform state rm aws_instance.removed

# Format and validate
terraform fmt                     # auto-format .tf files
terraform fmt -recursive          # all subdirectories
terraform validate

# Import existing resource
terraform import aws_s3_bucket.mybucket my-existing-bucket

# Workspace (environments)
terraform workspace list
terraform workspace new staging
terraform workspace select prod
```

### Basic structure

```
infra/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── terraform.tfvars
└── modules/
    └── vpc/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

**`versions.tf`**:

```hcl
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}
```

**`variables.tf`**:

```hcl
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
```

**`main.tf`** example:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.environment}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = var.environment != "prod"

  tags = var.common_tags
}

resource "aws_s3_bucket" "app" {
  bucket = "${var.environment}-myapp-assets"

  tags = merge(var.common_tags, {
    Name = "App Assets"
  })
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

---

## Multi-Cloud Reference

| Task | AWS | GCP | Azure |
|---|---|---|---|
| Object storage | S3 | Cloud Storage | Blob Storage |
| Container registry | ECR | Artifact Registry | ACR |
| Managed Kubernetes | EKS | GKE | AKS |
| Serverless | Lambda | Cloud Functions | Azure Functions |
| Managed DB | RDS | Cloud SQL | Azure SQL |
| Secrets | SSM / Secrets Manager | Secret Manager | Key Vault |
| CDN | CloudFront | Cloud CDN | Azure CDN |
| DNS | Route 53 | Cloud DNS | Azure DNS |
| Monitoring | CloudWatch | Cloud Monitoring | Azure Monitor |
| AI / ML | SageMaker | Vertex AI | Azure ML |
