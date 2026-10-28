# AWS (Amazon Web Services) Setup Guide

## Overview

Amazon Web Services (AWS) is the world's most comprehensive and widely adopted cloud platform, offering over 200 services from data centers globally. AWS provides on-demand compute, storage, networking, databases, machine learning, analytics, and much more.

---

## Core Services

| Service | Category | Description |
|---|---|---|
| **EC2** | Compute | Virtual servers in the cloud |
| **Lambda** | Compute | Serverless function execution |
| **ECS** | Containers | Docker container orchestration |
| **EKS** | Containers | Managed Kubernetes |
| **S3** | Storage | Object storage (unlimited scale) |
| **EBS** | Storage | Block storage for EC2 |
| **VPC** | Networking | Isolated virtual network |
| **Route 53** | Networking | DNS and domain management |
| **ALB/NLB** | Networking | Application and Network Load Balancers |
| **RDS** | Database | Managed relational databases |
| **DynamoDB** | Database | Managed NoSQL (key-value) |
| **ElastiCache** | Database | Managed Redis/Memcached |
| **IAM** | Security | Identity and access management |
| **CloudWatch** | Monitoring | Metrics, logs, and alarms |
| **CloudFormation** | IaC | Infrastructure as code (native) |
| **CodePipeline** | CI/CD | Managed CI/CD pipeline |
| **SNS/SQS** | Messaging | Pub/sub and message queuing |
| **ECR** | Containers | Docker container registry |

---

## AWS CLI Setup

### Installation

**macOS:**
```bash
brew install awscli
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Windows:**
```powershell
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
```

### Configuration

```bash
# Interactive configuration
aws configure

# Configure a named profile
aws configure --profile production

# Set environment variables (alternative)
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_DEFAULT_REGION=us-east-1

# Use SSO (recommended for organizations)
aws configure sso
```

Configuration is stored in `~/.aws/credentials` and `~/.aws/config`.

### Key CLI Commands

```bash
# Identity check
aws sts get-caller-identity

# EC2
aws ec2 describe-instances --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,Type:InstanceType,IP:PublicIpAddress}' --output table
aws ec2 start-instances --instance-ids i-1234567890abcdef0
aws ec2 stop-instances --instance-ids i-1234567890abcdef0

# S3
aws s3 ls
aws s3 cp file.txt s3://my-bucket/
aws s3 sync ./build s3://my-bucket/ --delete
aws s3 presign s3://my-bucket/file.txt --expires-in 3600

# CloudWatch Logs
aws logs tail /aws/lambda/my-function --follow
aws logs filter-log-events --log-group-name /aws/ecs/my-service --filter-pattern "ERROR"

# Lambda
aws lambda invoke --function-name my-function --payload '{"key":"value"}' output.json

# ECS
aws ecs list-clusters
aws ecs update-service --cluster my-cluster --service my-service --force-new-deployment

# ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com

# SSM (connect to EC2 without SSH keys)
aws ssm start-session --target i-1234567890abcdef0

# Cost
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-02-01 --granularity MONTHLY --metrics BlendedCost
```

---

## Key Services for DevOps Engineers

### EC2 (Elastic Compute Cloud)

```bash
# Launch an instance
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --instance-type t3.medium \
  --key-name my-key \
  --security-group-ids sg-12345 \
  --subnet-id subnet-12345 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MyServer}]'
```

Instance type selection guide:
| Family | Use Case | Example |
|---|---|---|
| t3/t4g | General purpose, burstable | Web servers, dev environments |
| m6i/m7g | General purpose, sustained | Application servers |
| c6i/c7g | Compute optimized | Batch processing, CI runners |
| r6i/r7g | Memory optimized | Caches, in-memory databases |
| i3/i4i | Storage optimized | Databases, data warehouses |

### S3 (Simple Storage Service)

Storage classes:

| Class | Use Case | Cost |
|---|---|---|
| Standard | Frequently accessed data | Highest |
| Intelligent-Tiering | Unknown access patterns | Auto-optimized |
| Standard-IA | Infrequent access | Lower storage, higher retrieval |
| Glacier Instant Retrieval | Archive, millisecond access | Very low storage |
| Glacier Deep Archive | Long-term archive | Lowest |

### VPC (Virtual Private Cloud)

Typical VPC architecture:
```
VPC (10.0.0.0/16)
├── Public Subnet (10.0.1.0/24) - AZ a
│   ├── NAT Gateway
│   └── ALB
├── Public Subnet (10.0.2.0/24) - AZ b
│   └── ALB
├── Private Subnet (10.0.10.0/24) - AZ a
│   └── App Servers
├── Private Subnet (10.0.11.0/24) - AZ b
│   └── App Servers
├── Private Subnet (10.0.20.0/24) - AZ a
│   └── Database
└── Private Subnet (10.0.21.0/24) - AZ b
    └── Database
```

### ECS (Elastic Container Service)

```bash
# Register a task definition
aws ecs register-task-definition --cli-input-json file://task-definition.json

# Create a service
aws ecs create-service \
  --cluster my-cluster \
  --service-name my-service \
  --task-definition my-task:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-12345],securityGroups=[sg-12345],assignPublicIp=ENABLED}"
```

### EKS (Elastic Kubernetes Service)

```bash
# Create cluster (use eksctl for simplicity)
eksctl create cluster \
  --name my-cluster \
  --region us-east-1 \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 3 \
  --managed

# Update kubeconfig
aws eks update-kubeconfig --name my-cluster --region us-east-1

# Use EKS add-ons
aws eks create-addon --cluster-name my-cluster --addon-name vpc-cni
aws eks create-addon --cluster-name my-cluster --addon-name coredns
aws eks create-addon --cluster-name my-cluster --addon-name kube-proxy
```

---

## IAM Best Practices

1. **Enable MFA** on the root account and all human users
2. **Never use the root account** for daily tasks
3. **Use IAM roles** for applications and services (not long-lived access keys)
4. **Apply least privilege**: Start with minimal permissions, add as needed
5. **Use IAM policies with conditions**: Restrict by IP, time, MFA status
6. **Rotate credentials** regularly; prefer temporary credentials (STS)
7. **Use AWS Organizations** with Service Control Policies (SCPs) for multi-account governance
8. **Use IAM Identity Center (SSO)** for federated access across accounts

Example least-privilege policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-app-bucket/*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

---

## Cost Optimization Tips

1. **Right-size instances**: Use AWS Compute Optimizer to identify over-provisioned resources
2. **Reserved Instances / Savings Plans**: Commit for 1-3 years for up to 72% savings on steady-state workloads
3. **Spot Instances**: Use for fault-tolerant workloads (CI/CD runners, batch jobs) at up to 90% discount
4. **S3 Lifecycle Policies**: Automatically transition data to cheaper storage classes
5. **Delete unused resources**: EBS volumes, old snapshots, unattached Elastic IPs, idle load balancers
6. **Use AWS Cost Explorer**: Monitor spending trends and set budgets with AWS Budgets
7. **Graviton instances**: ARM-based instances (t4g, m7g, c7g) offer better price-performance
8. **NAT Gateway costs**: Consider VPC endpoints for S3/DynamoDB to avoid NAT Gateway data charges
9. **Tag everything**: Use cost allocation tags to attribute costs to teams and projects

---

## Infrastructure Patterns

### Three-Tier Architecture

```
Internet
  │
  ▼
ALB (Public Subnets)
  │
  ▼
App Tier - EC2/ECS/EKS (Private Subnets)
  │
  ▼
Data Tier - RDS/ElastiCache (Private Subnets)
```

### Serverless Architecture

```
API Gateway → Lambda → DynamoDB
                │
                ├── S3 (file storage)
                ├── SQS (async processing)
                ├── SNS (notifications)
                └── Step Functions (workflows)
```

### Microservices on ECS/EKS

```
Route 53 → CloudFront → ALB
                          │
              ┌───────────┼───────────┐
              ▼           ▼           ▼
          Service A   Service B   Service C
          (ECS/EKS)   (ECS/EKS)   (ECS/EKS)
              │           │           │
              ▼           ▼           ▼
           RDS        DynamoDB    ElastiCache
```

---

## AWS CDK (Cloud Development Kit)

AWS CDK lets you define infrastructure using programming languages (TypeScript, Python, Go, Java, C#).

```bash
# Install CDK
npm install -g aws-cdk

# Initialize a new project
cdk init app --language typescript

# Synthesize CloudFormation
cdk synth

# Deploy
cdk deploy

# Diff (preview changes)
cdk diff
```

Example CDK stack (TypeScript):

```typescript
import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as ecs_patterns from 'aws-cdk-lib/aws-ecs-patterns';

export class MyStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string) {
    super(scope, id);

    const vpc = new ec2.Vpc(this, 'Vpc', { maxAzs: 2 });
    const cluster = new ecs.Cluster(this, 'Cluster', { vpc });

    new ecs_patterns.ApplicationLoadBalancedFargateService(this, 'Service', {
      cluster,
      taskImageOptions: {
        image: ecs.ContainerImage.fromRegistry('nginx'),
      },
      desiredCount: 2,
      publicLoadBalancer: true,
    });
  }
}
```

---

## AWS Copilot

AWS Copilot simplifies building, releasing, and operating containerized applications on ECS and App Runner.

```bash
# Install
brew install aws/tap/copilot-cli

# Initialize application
copilot init

# Deploy an environment
copilot env init --name production --profile prod

# Deploy a service
copilot svc deploy

# View logs
copilot svc logs --follow

# Add a pipeline
copilot pipeline init
copilot pipeline deploy
```

---

## AWS App Runner

Fully managed service for containerized web applications (no infrastructure to manage).

```bash
# Create service from container image
aws apprunner create-service \
  --service-name my-api \
  --source-configuration '{
    "ImageRepository": {
      "ImageIdentifier": "123456789.dkr.ecr.us-east-1.amazonaws.com/my-app:latest",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "8080"
      }
    },
    "AutoDeploymentsEnabled": true,
    "AuthenticationConfiguration": {
      "AccessRoleArn": "arn:aws:iam::123456789:role/AppRunnerECRAccess"
    }
  }'
```

---

## Best Practices

1. **Multi-account strategy**: Use AWS Organizations with separate accounts for dev, staging, production, and security
2. **Infrastructure as Code**: Use CloudFormation, CDK, or Terraform for all resources. Never create production resources manually
3. **Encryption**: Enable encryption at rest (S3, EBS, RDS) and in transit (TLS). Use AWS KMS for key management
4. **Logging and auditing**: Enable CloudTrail in all regions. Send logs to a centralized security account
5. **Networking**: Use VPC endpoints, private subnets, and security groups. Follow the principle of least connectivity
6. **Disaster recovery**: Use multi-AZ deployments. Define RTO/RPO and test recovery procedures regularly
7. **Automation**: Use Systems Manager for patching, Config for compliance, and GuardDuty for threat detection
8. **Tagging strategy**: Enforce consistent tagging via SCPs for cost allocation, automation, and access control

---

## Resources

- [AWS Documentation](https://docs.aws.amazon.com/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS CLI Reference](https://awscli.amazonaws.com/v2/documentation/api/latest/index.html)
- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/v2/guide/home.html)
- [AWS Architecture Center](https://aws.amazon.com/architecture/)
- [AWS Pricing Calculator](https://calculator.aws/)
- [AWS re:Post (Community)](https://repost.aws/)
- [eksctl Documentation](https://eksctl.io/)
