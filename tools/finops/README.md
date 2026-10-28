# FinOps — Cloud Cost Management

> Bring financial accountability to cloud spending. Optimize costs without sacrificing reliability.

## FinOps Lifecycle

```
INFORM → OPTIMIZE → OPERATE
  │           │          │
Visibility  Actions    Culture
  │           │          │
Tagging    Reserved   Teams own
Dashboards Instances  their costs
Anomaly    Auto-stop  Chargebacks
Detection  Rightsizing Budgets
```

## Quick Wins (Do These First)

```
1. Turn off dev/staging environments nights & weekends → 60% savings on non-prod
2. Delete unattached EBS volumes → instant savings
3. Release unused Elastic IPs → $0.005/hr per IP
4. Right-size over-provisioned EC2 instances → 30-50% savings
5. Switch to Graviton (ARM) instances → 20% savings, same performance
6. Enable S3 Intelligent-Tiering → automatic storage cost reduction
7. Delete old snapshots → check age > 30 days
8. Review NAT Gateway data transfer → often the hidden cost killer
```

## AWS Cost Tools

```bash
# AWS Cost Explorer CLI
aws ce get-cost-and-usage \
  --time-period Start=2026-03-01,End=2026-04-01 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Get cost by tag
aws ce get-cost-and-usage \
  --time-period Start=2026-03-01,End=2026-04-01 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Environment

# Find unattached EBS volumes (waste!)
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query 'Volumes[*].{ID:VolumeId,Size:Size,Type:VolumeType,AZ:AvailabilityZone}' \
  --output table

# Find idle EC2 instances (< 5% CPU avg)
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --statistics Average \
  --period 604800 \
  --start-time 2026-03-01T00:00:00Z \
  --end-time 2026-04-01T00:00:00Z \
  --dimensions Name=InstanceId,Value=i-xxxxxxxxx

# List all Elastic IPs (pay per unattached one)
aws ec2 describe-addresses \
  --query 'Addresses[?!AssociationId].[PublicIp,AllocationId]' \
  --output table

# Find old snapshots (> 30 days)
aws ec2 describe-snapshots \
  --owner-ids self \
  --query 'Snapshots[?StartTime<=`2026-03-01`].[SnapshotId,StartTime,VolumeSize]' \
  --output table

# Check NAT Gateway data transfer costs
aws cloudwatch get-metric-statistics \
  --namespace AWS/NatGateway \
  --metric-name BytesOutToDestination \
  --statistics Sum \
  --period 86400 \
  --start-time 2026-03-01T00:00:00Z \
  --end-time 2026-04-01T00:00:00Z
```

## Kubernetes Resource Optimization

```bash
# Install Goldilocks — auto right-sizing recommendations
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm install goldilocks fairwinds-stable/goldilocks -n goldilocks --create-namespace

# Enable namespace for analysis
kubectl label namespace production goldilocks.fairwinds.com/enabled=true

# View recommendations in UI
kubectl port-forward -n goldilocks svc/goldilocks-dashboard 8080:80
# Open http://localhost:8080

# VPA (Vertical Pod Autoscaler) — auto right-size pods
kubectl apply -f https://github.com/kubernetes/autoscaler/releases/latest/download/vertical-pod-autoscaler.yaml

# Create VPA in recommend mode (no automatic changes)
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: payment-service-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: payment-service
  updatePolicy:
    updateMode: "Off"  # Only recommend, don't change
EOF

# Check VPA recommendations
kubectl describe vpa payment-service-vpa

# Kubecost — cloud cost monitoring for K8s
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost --create-namespace \
  --set kubecostToken="your-token"
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090
```

## Tagging Strategy (Foundation of FinOps)

```bash
# Every resource MUST have these tags
required_tags = {
  "team": "payments",           # Who owns this?
  "service": "checkout-api",    # Which service?
  "environment": "production",  # dev|staging|production
  "cost-center": "CC-1234",    # For billing allocation
  "managed-by": "terraform",   # How is this managed?
}

# AWS Config rule to enforce tagging
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "required-tags",
    "Source": {"Owner": "AWS", "SourceIdentifier": "REQUIRED_TAGS"},
    "InputParameters": "{\"tag1Key\":\"team\",\"tag2Key\":\"environment\"}"
  }'

# Find untagged resources
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=team \
  --query 'ResourceTagMappingList[?Tags[?Key==`team`] == `[]`]'
```

## Auto-Scheduling (Stop Dev Environments at Night)

```bash
# AWS Instance Scheduler (saves ~60% on dev costs)
# Tag EC2 instances with:
aws ec2 create-tags --resources i-xxxxxxxxx \
  --tags Key=Schedule,Value=mon-fri-0800-1800

# Or use simple Lambda + EventBridge
# Stop all dev instances at 8 PM EST
aws events put-rule \
  --name "stop-dev-instances-night" \
  --schedule-expression "cron(0 1 * * ? *)" \  # 8 PM EST = 01:00 UTC
  --state ENABLED

# Kubernetes — scale down non-prod at night
# Install kube-downscaler
helm repo add codeberg https://codeberg.org/hjacobs/charts
helm install kube-downscaler codeberg/kube-downscaler

# Annotate namespaces to scale down at night
kubectl annotate namespace staging \
  "downscaler/uptime=Mon-Fri 08:00-20:00 US/Eastern"
```

## Savings Plans & Reserved Instances

```bash
# Check Reserved Instance recommendations
aws ce get-reservation-purchase-recommendation \
  --service "Amazon EC2" \
  --lookback-period-in-days THIRTY_DAYS \
  --term-in-years ONE_YEAR \
  --payment-option PARTIAL_UPFRONT

# Check Savings Plans recommendations
aws ce get-savings-plans-purchase-recommendation \
  --savings-plans-type COMPUTE_SP \
  --term-in-years ONE_YEAR \
  --payment-option PARTIAL_UPFRONT \
  --lookback-period-in-days THIRTY_DAYS
```

## Cost Anomaly Detection

```bash
# Set up cost anomaly detection
aws ce create-anomaly-monitor \
  --anomaly-monitor '{
    "MonitorName": "ServiceMonitor",
    "MonitorType": "DIMENSIONAL",
    "MonitorDimension": "SERVICE"
  }'

# Create alert subscription (notify when spend is anomalous)
aws ce create-anomaly-subscription \
  --anomaly-subscription '{
    "MonitorArnList": ["arn:aws:ce::123456789:anomalymonitor/xxxx"],
    "Subscribers": [{"Address": "finops@company.com", "Type": "EMAIL"}],
    "Threshold": 20,
    "Frequency": "DAILY",
    "SubscriptionName": "DailyCostAlert"
  }'
```

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/aws_cost_report.py` | Weekly cost breakdown by team/service |
| `scripts/k8s_resource_optimizer.py` | K8s right-sizing recommendations |
| `scripts/cloud_waste_finder.sh` | Find idle/unused cloud resources |
| `scripts/cost_anomaly_alert.py` | Alert on unexpected spend increases |
| `scripts/auto_stop_dev.sh` | Stop development environments off-hours |

## FinOps Tools

| Tool | Description | Cost |
|------|-------------|------|
| **AWS Cost Explorer** | Native AWS cost analysis | Free |
| **Kubecost** | K8s cost allocation | Free tier |
| **Infracost** | Terraform cost estimates in PRs | Open source |
| **CloudHealth** | Multi-cloud cost management | Paid |
| **Spot.io** | Spot instance automation | % of savings |
| **CAST AI** | K8s cost optimization | % of savings |
