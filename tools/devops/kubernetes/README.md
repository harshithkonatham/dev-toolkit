# Kubernetes (K8s) - Container Orchestration

## Overview

Kubernetes (K8s) is an open-source container orchestration platform originally designed by Google and now maintained by the Cloud Native Computing Foundation (CNCF). It automates the deployment, scaling, and management of containerized workloads across clusters of machines.

Kubernetes provides a declarative API for defining the desired state of your infrastructure. The control plane continuously works to make the actual state match your declared intent.

## Why Use Kubernetes?

| Benefit | Description |
|---|---|
| **Self-healing** | Automatically restarts failed containers, replaces pods, and kills unresponsive ones |
| **Horizontal scaling** | Scale workloads up or down based on CPU, memory, or custom metrics |
| **Service discovery** | Built-in DNS and load balancing between pods |
| **Rolling updates** | Zero-downtime deployments with rollback capability |
| **Secret management** | Native support for managing sensitive configuration |
| **Storage orchestration** | Mount local, cloud, or network storage automatically |
| **Declarative config** | Infrastructure as code via YAML manifests |
| **Ecosystem** | Massive ecosystem of tools, operators, and integrations |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Control Plane                         │
│  ┌──────────────┐  ┌───────────┐  ┌────────────────────┐   │
│  │  API Server   │  │ Scheduler │  │ Controller Manager │   │
│  └──────────────┘  └───────────┘  └────────────────────┘   │
│  ┌──────────────┐  ┌──────────────────────────────────┐     │
│  │    etcd       │  │  Cloud Controller Manager (opt)  │     │
│  └──────────────┘  └──────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘

┌────────────────────┐  ┌────────────────────┐
│      Node 1        │  │      Node 2        │
│  ┌──────────────┐  │  │  ┌──────────────┐  │
│  │   kubelet    │  │  │  │   kubelet    │  │
│  ├──────────────┤  │  │  ├──────────────┤  │
│  │  kube-proxy  │  │  │  │  kube-proxy  │  │
│  ├──────────────┤  │  │  ├──────────────┤  │
│  │  Container   │  │  │  │  Container   │  │
│  │  Runtime     │  │  │  │  Runtime     │  │
│  ├──────────────┤  │  │  ├──────────────┤  │
│  │ Pod Pod Pod  │  │  │  │ Pod Pod Pod  │  │
│  └──────────────┘  │  │  └──────────────┘  │
└────────────────────┘  └────────────────────┘
```

### Key Components

- **API Server** -- Central management point; all communication goes through it
- **etcd** -- Distributed key-value store holding all cluster state
- **Scheduler** -- Assigns pods to nodes based on resource requirements and constraints
- **Controller Manager** -- Runs controllers (ReplicaSet, Deployment, Job, etc.)
- **kubelet** -- Agent on each node that ensures containers are running as specified
- **kube-proxy** -- Manages network rules for Service communication

## Installation

### Local Development Clusters

#### minikube

```bash
# macOS
brew install minikube
minikube start --driver=docker --memory=4096 --cpus=2

# Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube start
```

#### kind (Kubernetes in Docker)

```bash
# macOS / Linux
brew install kind
# or
go install sigs.k8s.io/kind@latest

# Create cluster
kind create cluster --name dev

# Create multi-node cluster
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF
```

#### k3s (Lightweight Kubernetes)

```bash
# Single-node install (Linux)
curl -sfL https://get.k3s.io | sh -
sudo k3s kubectl get nodes
```

### Managed Kubernetes (Cloud)

```bash
# AWS EKS
eksctl create cluster --name my-cluster --region us-east-1 --nodes 3

# Google GKE
gcloud container clusters create my-cluster --zone us-central1-a --num-nodes 3

# Azure AKS
az aks create --resource-group myRG --name my-cluster --node-count 3
```

### kubectl Installation

```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl

# Verify
kubectl version --client
```

## kubectl Cheat Sheet

### Context and Configuration

```bash
kubectl config get-contexts                   # List contexts
kubectl config use-context my-cluster         # Switch context
kubectl config set-context --current --namespace=dev  # Set default namespace
kubectl cluster-info                          # Cluster info
```

### Core Operations

```bash
# Get resources
kubectl get pods                              # List pods
kubectl get pods -o wide                      # With node and IP info
kubectl get pods -A                           # All namespaces
kubectl get deploy,svc,ing                    # Multiple resource types
kubectl get all                               # Common resources in namespace

# Describe (detailed info)
kubectl describe pod my-pod
kubectl describe node my-node

# Create / Apply
kubectl apply -f manifest.yaml                # Declarative create/update
kubectl apply -f ./manifests/                 # Apply entire directory
kubectl apply -k ./overlays/production/       # Apply Kustomize overlay

# Delete
kubectl delete -f manifest.yaml
kubectl delete pod my-pod
kubectl delete pod my-pod --grace-period=0 --force  # Force delete

# Logs
kubectl logs my-pod                           # Pod logs
kubectl logs my-pod -c my-container           # Specific container
kubectl logs -f my-pod                        # Follow logs
kubectl logs -l app=web --all-containers      # Logs by label

# Exec
kubectl exec -it my-pod -- /bin/sh            # Shell into pod
kubectl exec my-pod -- env                    # Run command

# Port forwarding
kubectl port-forward svc/my-service 8080:80   # Forward local 8080 to service port 80

# Scaling
kubectl scale deployment web --replicas=5
kubectl autoscale deployment web --min=2 --max=10 --cpu-percent=70
```

### Debugging

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl top pods                              # Resource usage (requires metrics-server)
kubectl top nodes
kubectl run debug --rm -it --image=busybox -- sh  # Ephemeral debug pod
kubectl debug my-pod -it --image=busybox      # Debug existing pod
```

## Core Concepts

### Pod

The smallest deployable unit. Usually one container per pod, but sidecar patterns use multiple.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
  labels:
    app: web
spec:
  containers:
    - name: web
      image: nginx:1.27-alpine
      ports:
        - containerPort: 80
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
      livenessProbe:
        httpGet:
          path: /healthz
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 10
      readinessProbe:
        httpGet:
          path: /ready
          port: 80
        initialDelaySeconds: 3
        periodSeconds: 5
```

### Deployment

Manages ReplicaSets and provides declarative updates, rolling deployments, and rollbacks.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: myapp:1.0.0
          ports:
            - containerPort: 8080
          env:
            - name: DB_HOST
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: db_host
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: db_password
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "512Mi"
```

### Service

Exposes pods via a stable network endpoint.

```yaml
# ClusterIP (internal only, default)
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP
---
# LoadBalancer (external, provisions cloud LB)
apiVersion: v1
kind: Service
metadata:
  name: web-public
spec:
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080
  type: LoadBalancer
```

| Service Type | Scope | Use Case |
|---|---|---|
| `ClusterIP` | Internal only | Inter-service communication |
| `NodePort` | External via node IP:port | Development, on-prem |
| `LoadBalancer` | External via cloud LB | Production cloud workloads |
| `ExternalName` | DNS alias | Referencing external services |

### ConfigMap and Secret

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  db_host: "postgres.default.svc.cluster.local"
  log_level: "info"
  config.yaml: |
    server:
      port: 8080
      debug: false
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  db_password: cGFzc3dvcmQxMjM=   # base64 encoded
```

### Ingress

Routes external HTTP/HTTPS traffic to services.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - app.example.com
      secretName: app-tls
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
```

### Namespace

```bash
kubectl create namespace staging
kubectl get pods -n staging
```

## Helm - Package Manager

Helm packages Kubernetes manifests into reusable, versioned **charts**.

```bash
# Install Helm
brew install helm   # macOS
# or
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Add a chart repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Search for charts
helm search repo nginx

# Install a chart
helm install my-nginx bitnami/nginx --namespace web --create-namespace

# Install with custom values
helm install my-app ./my-chart -f values-prod.yaml --set image.tag=1.2.3

# List releases
helm list -A

# Upgrade
helm upgrade my-app ./my-chart -f values-prod.yaml

# Rollback
helm rollback my-app 1

# Uninstall
helm uninstall my-app
```

## Monitoring with Prometheus and Grafana

```bash
# Install kube-prometheus-stack via Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin

# Access Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# Open http://localhost:3000 (admin / admin)
```

## Modern Kubernetes Features

### Gateway API

The Gateway API is the successor to Ingress, offering more expressive routing.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: main-gateway
spec:
  gatewayClassName: istio
  listeners:
    - name: http
      port: 80
      protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
spec:
  parentRefs:
    - name: main-gateway
  hostnames:
    - "app.example.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: api-service
          port: 8080
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: frontend-service
          port: 3000
```

### Kustomize

Built into `kubectl`, Kustomize provides template-free customization of manifests.

```
# Directory structure
base/
  kustomization.yaml
  deployment.yaml
  service.yaml
overlays/
  production/
    kustomization.yaml
    replicas-patch.yaml
  staging/
    kustomization.yaml
```

```yaml
# base/kustomization.yaml
resources:
  - deployment.yaml
  - service.yaml

# overlays/production/kustomization.yaml
resources:
  - ../../base
namePrefix: prod-
patches:
  - path: replicas-patch.yaml
```

```bash
kubectl apply -k overlays/production/
```

### ArgoCD (GitOps)

ArgoCD synchronizes Kubernetes state with Git repositories.

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial admin password
argocd admin initial-password -n argocd

# Create an Application
argocd app create my-app \
  --repo https://github.com/org/repo.git \
  --path k8s/overlays/production \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace production \
  --sync-policy automated
```

## Best Practices

1. **Always set resource requests and limits** -- prevents noisy-neighbor issues and enables the scheduler to make good decisions
2. **Use namespaces** -- separate teams, environments, or applications
3. **Use labels and selectors consistently** -- enables filtering, monitoring, and policy enforcement
4. **Define liveness and readiness probes** -- ensures traffic only reaches healthy pods
5. **Use Deployments, not bare Pods** -- get rolling updates, scaling, and self-healing
6. **Store config in ConfigMaps, secrets in Secrets** -- never bake environment-specific values into images
7. **Use RBAC** -- follow the principle of least privilege for service accounts
8. **Implement NetworkPolicies** -- restrict pod-to-pod communication to what is actually needed
9. **Use PodDisruptionBudgets** -- ensure availability during voluntary disruptions
10. **Pin image tags** -- never use `latest` in production manifests
11. **Use GitOps** -- manage cluster state via Git with ArgoCD or Flux

## Resources

- [Official Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Kubernetes The Hard Way (Kelsey Hightower)](https://github.com/kelseyhightower/kubernetes-the-hard-way)
- [CNCF Landscape](https://landscape.cncf.io/)
- [Kustomize Documentation](https://kustomize.io/)
