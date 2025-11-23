# Deployment Guide

This guide walks through deploying CarePath to AWS EKS with MongoDB Atlas.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Configuration](#configuration)
4. [Step-by-Step Deployment](#step-by-step-deployment)
5. [Finding Service URLs](#finding-service-urls)
6. [Frontend Deployment](#frontend-deployment)
7. [Verification](#verification)
8. [Operations & Contingencies](#operations--contingencies)
   - [Scaling Up/Down](#i-scaling-updown)
   - [Rolling Out Updates](#ii-rolling-out-updates)
   - [Rollbacks](#iii-rollbacks)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- AWS CLI configured with SSO profile
- Terraform >= 1.0
- Docker
- kubectl
- Node.js 18+ and npm (for frontend)
- MongoDB Atlas account with organization ID

---

## Environment Setup

### 1. Configure Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

Key variables for deployment:
```bash
# AWS Configuration
DEPLOY_AWS_REGION=us-east-1
DEPLOY_AWS_PROFILE=your-sso-profile
DEPLOY_AWS_ACCOUNT_ID=123456789012

# Terraform State (can reuse existing backend from other projects)
DEPLOY_TF_STATE_BUCKET_NAME=your-terraform-state-bucket
DEPLOY_TF_DYNAMO_DB_TABLE=your-terraform-state-locks

# MongoDB (your existing cluster connection string)
MONGODB_URI=mongodb+srv://user:password@your-cluster.mongodb.net/?retryWrites=true&w=majority
MONGODB_DB_NAME=carepath
```

### 2. Configure Terraform Backend

Create the backend configuration file:

```bash
cp infra/terraform/envs/demo/backend.hcl.example infra/terraform/envs/demo/backend.hcl
```

Edit `backend.hcl` with your values:
```hcl
bucket         = "your-terraform-state-bucket"    # e.g., genonaut-terraform-state
key            = "carepath/demo/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "your-terraform-state-locks"     # e.g., genonaut-terraform-state-locks
encrypt        = true
```

**Note:** You can safely reuse an existing Terraform state backend from other projects. Each project uses a unique `key`
path, so state files don't interfere with each other.

### 3. Configure Terraform Variables

Create the variables file:

```bash
cp infra/terraform/envs/demo/terraform.tfvars.example infra/terraform/envs/demo/terraform.tfvars
```

Edit `terraform.tfvars` with your MongoDB URI:
```hcl
environment = "demo"
aws_region  = "us-east-1"

# Use your existing MongoDB cluster
mongodb_uri           = "mongodb+srv://user:password@your-cluster.mongodb.net/?retryWrites=true&w=majority"
mongodb_database_name = "carepath"
```

**Note:** If you want Terraform to create a new MongoDB Atlas cluster instead, set `create_mongodb_atlas = true` and
provide the Atlas API keys. See `terraform.tfvars.example` for details.

---

## Configuration

### EC2 Node Capacity Type

EKS worker nodes can run as either **On-Demand** or **Spot** instances. This setting affects AWS quota usage and cost.

| Type | Description | When to Use |
|------|-------------|-------------|
| `ON_DEMAND` | Standard EC2 instances | Production, stable workloads |
| `SPOT` | Discounted instances (can be interrupted) | Development, demos, cost savings |

**Why SPOT exists:** New AWS accounts have restrictive quotas on On-Demand EC2 "Fleet Requests." If you hit quota limits during deployment, switching to SPOT instances uses a different quota pool and often resolves the issue. SPOT instances are also 60-90% cheaper.

**Check current setting:**
```bash
make ec2-config-status
```

**Switch to SPOT instances:**
```bash
make ec2-config-set-as-spot
```

**Switch to On-Demand (standard) instances:**
```bash
make ec2-config-set-as-nodes
```

**Note:** After changing this setting, you must delete any existing/failed node group and run `make tf-apply` for changes to take effect. See [Troubleshooting](#troubleshooting) for details.

### DB API External Access

By default in the demo environment, the db-api is exposed externally via a LoadBalancer so you can query it directly (useful for demos and frontend development). In production, you'd typically keep it internal-only.

| Setting | Service Type | Access |
|---------|--------------|--------|
| `expose_db_api = true` | LoadBalancer | Publicly accessible via ELB URL |
| `expose_db_api = false` | ClusterIP | Internal only (within cluster) |

**Check current setting:**
```bash
kubectl get svc db-api-service -n carepath-demo -o jsonpath='{.spec.type}'
```

**To change:** Edit `infra/terraform/envs/demo/variables.tf`:
```hcl
variable "expose_db_api" {
  ...
  default = true   # true = external, false = internal only
}
```

Then run `make tf-apply`.

**Security Note:** When `expose_db_api = true`, anyone can query your database API. This is fine for demos but for production you should:
- Keep it internal (`expose_db_api = false`)
- Or add authentication/API keys
- Or use an API Gateway with auth

### AWS Region

Infrastructure can be deployed to different AWS regions. This is useful if you hit quota limits in one region but have approved quotas in another.

| Region | Location | Notes |
|--------|----------|-------|
| `us-east-1` | N. Virginia | Default, most services available |
| `us-east-2` | Ohio | Alternative if us-east-1 quotas are exhausted |

**Check current region:**
```bash
make region-status
```

**Switch to us-east-2 (Ohio):**
```bash
make region-set-us-east-2
```

**Switch to us-east-1 (N. Virginia):**
```bash
make region-set-us-east-1
```

**Important:** Changing regions is a destructive operation. You must:

1. **Destroy existing infrastructure first:**
   ```bash
   make tf-destroy
   ```

2. **Run the region switch command** (it will prompt for confirmation)

3. **Deploy to the new region:**
   ```bash
   make tf-apply
   ```

**Note:** The Terraform state bucket (in `backend.hcl`) stays in us-east-1 regardless of where you deploy. S3 buckets are globally accessible, so you don't need to change it or run bootstrap commands again.

---

## Step-by-Step Deployment

### Step 1: AWS Login

```bash
make aws-login
```

This authenticates via AWS SSO and verifies your credentials.

### Step 2: Initialize Terraform

```bash
make tf-init
```

This initializes Terraform with your backend configuration.

### Step 3: Review Infrastructure Plan

```bash
make tf-plan
```

Review the planned changes carefully. This will show you what resources will be created:
- VPC with public/private subnets
- EKS cluster with managed node group
- ECR repositories for Docker images
- MongoDB Atlas cluster
- Kubernetes namespace, deployments, and services

### Step 4: Apply Infrastructure

```bash
make tf-apply
```

This creates all the infrastructure. **This may take 15-20 minutes** (EKS cluster creation is slow).

**Note:** If you encounter errors during this step, see the [Troubleshooting](#troubleshooting) section for common issues and solutions.

### Step 5: Configure kubectl

After Terraform completes, configure kubectl to connect to your EKS cluster:

```bash
make k8s-config
```

### Step 6: Build and Push Docker Images

```bash
# Build both images
make docker-build-db-api
make docker-build-chat

# Push both to ECR
make docker-push-db-api
make docker-push-chat
```

### Step 7: Deploy Services to Kubernetes

```bash
# Deploy both services
make deploy-all
```

Or deploy individually:
```bash
make deploy-db-api
make deploy-chat
```

---

## Finding Service URLs

After deployment, get the service URLs:

```bash
make k8s-get-urls
```

This shows:
- **Chat API URL**: External LoadBalancer URL (publicly accessible)
- **DB API URL**: External LoadBalancer URL if `expose_db_api = true` (default for demo), otherwise internal ClusterIP

**Note:** LoadBalancer URLs may take 2-3 minutes to provision after deployment.

You can also check all resources:

```bash
make k8s-status
```

---

## Frontend Deployment

The CarePath frontend is a React app hosted on AWS S3 with CloudFront CDN. This provides a simple web UI for chatting with the CarePath AI and viewing chat history.

### Prerequisites

- Node.js 18+ and npm
- Backend APIs already deployed (db-api and chat-api)
- Terraform frontend infrastructure created (`make tf-apply`)

### Configuration

Create a `.env` file in `frontend_chat/`:

```bash
cd frontend_chat
cp .env.example .env
```

Edit `.env` with your API URLs (get these from `make k8s-get-urls`):
```bash
VITE_DB_API_URL=http://your-db-api-loadbalancer.elb.amazonaws.com
VITE_CHAT_API_URL=http://your-chat-api-loadbalancer.elb.amazonaws.com
```

### Deploy Frontend

```bash
# Install dependencies (first time only)
make frontend-install

# Build and deploy to S3/CloudFront
make frontend-deploy
```

This will:
1. Build the React app for production
2. Sync the build output to S3
3. Invalidate the CloudFront cache
4. Print the frontend URL

### Local Development

To run the frontend locally:

```bash
make frontend-dev
```

The dev server starts at `http://localhost:5173` with hot reload.

### Frontend Makefile Commands

| Command | Description |
|---------|-------------|
| `make frontend-install` | Install npm dependencies |
| `make frontend-dev` | Run local dev server |
| `make frontend-build` | Build for production |
| `make frontend-deploy` | Build and deploy to S3/CloudFront |
| `make frontend-invalidate-cache` | Invalidate CloudFront cache |

### Frontend Configuration Variables

The following Terraform variables control frontend deployment:

| Variable | Default | Description |
|----------|---------|-------------|
| `expose_frontend` | `true` | Whether to create S3/CloudFront resources |
| `frontend_bucket_name` | `carepath-demo-frontend` | S3 bucket name for static files |

---

## Verification

### 1. Check Deployment Status

```bash
make k8s-status
```

All pods should show `Running` status with `1/1` ready.

### 2. Check Pod Logs

```bash
# View db-api logs
make k8s-logs s=db-api

# View chat-api logs
make k8s-logs s=chat-api
```

### 3. Test Health Endpoints

Get the Chat API URL first:
```bash
make k8s-get-urls
```

Then test:
```bash
# Replace with your actual LoadBalancer URL
CHAT_URL="http://your-loadbalancer-url.elb.amazonaws.com"

# Test chat-api health
curl $CHAT_URL/health

# Test db-api health (via chat-api, since db-api is internal)
# The chat-api calls db-api internally, so if triage works, both are healthy
```

### 4. Test the Triage Endpoint

```bash
curl -X POST $CHAT_URL/triage \
  -H "Content-Type: application/json" \
  -d '{"patient_mrn": "P000123", "query": "What are my current medications?"}'
```

Expected response includes `response`, `trace_id`, `conversation_id`, etc.

---

## Operations & Contingencies

### (i) Scaling Up/Down

The deployments have HPA (Horizontal Pod Autoscaler) configured, but you can manually scale:

**Scale Up:**
```bash
# Scale db-api to 3 replicas
make k8s-scale-up s=db-api r=3

# Scale chat-api to 3 replicas
make k8s-scale-up s=chat-api r=3
```

**Scale Down:**
```bash
# Scale db-api to 1 replica
make k8s-scale-down s=db-api r=1

# Scale chat-api to 1 replica
make k8s-scale-down s=chat-api r=1
```

**Check current scale:**
```bash
make k8s-status
```

### (ii) Rolling Out Updates

When you make code changes and want to deploy:

**Option A: Deploy a single service**
```bash
# This builds, pushes, and deploys in one command
make deploy-db-api   # or
make deploy-chat
```

**Option B: Deploy all services**
```bash
make deploy-all
```

**Option C: Just restart pods (same image)**
```bash
make k8s-restart-db-api
make k8s-restart-chat
```

**View rollout history:**
```bash
make k8s-history
```

For more deployment strategies (canary, blue-green, etc.), see [Rollout Options](deploy-rollout-options.md).

### (iii) Rollbacks

If something goes wrong after a deployment, rollback to the previous version:

**Rollback a single service:**
```bash
# Rollback db-api
make k8s-rollback-db-api

# Rollback chat-api
make k8s-rollback-chat
```

**Rollback all services:**
```bash
make k8s-rollback-all
```

**View rollout history (to see available revisions):**
```bash
make k8s-history
```

**Rollback to a specific revision (manual):**
```bash
kubectl rollout undo deployment/chat-api -n carepath-demo --to-revision=2
```

### (iv) Emergency Procedures

**If pods are crashing:**
1. Check logs: `make k8s-logs s=chat-api`
2. Check events: `kubectl describe pod <pod-name> -n carepath-demo`
3. Rollback: `make k8s-rollback-chat`

**If LoadBalancer is unreachable:**
1. Check service: `kubectl get svc -n carepath-demo`
2. Check pod readiness: `make k8s-pods`
3. Restart pods: `make k8s-restart-chat`

**If you need to completely redeploy:**
```bash
# Delete and recreate the deployment
kubectl delete deployment chat-api -n carepath-demo
make deploy-chat
```

---

## Makefile Command Reference

| Command | Description |
|---------|-------------|
| `make k8s-config` | Configure kubectl for EKS |
| `make k8s-status` | Show all deployments, pods, services, HPA |
| `make k8s-get-urls` | Get service URLs |
| `make k8s-pods` | List all pods with details |
| `make k8s-logs s=SERVICE` | Stream logs (s=db-api or chat-api) |
| `make k8s-scale-up s=SERVICE r=N` | Scale up to N replicas |
| `make k8s-scale-down s=SERVICE r=N` | Scale down to N replicas |
| `make k8s-rollback-db-api` | Rollback db-api |
| `make k8s-rollback-chat` | Rollback chat-api |
| `make k8s-rollback-all` | Rollback both services |
| `make k8s-restart-db-api` | Rolling restart db-api |
| `make k8s-restart-chat` | Rolling restart chat-api |
| `make k8s-history` | View rollout history |
| `make deploy-db-api` | Build, push, deploy db-api |
| `make deploy-chat` | Build, push, deploy chat-api |
| `make deploy-all` | Deploy all services |
| `make ec2-config-status` | Show current EC2 capacity type |
| `make ec2-config-set-as-nodes` | Use On-Demand EC2 instances |
| `make ec2-config-set-as-spot` | Use SPOT instances (different quota) |
| `make region-status` | Show current AWS region |
| `make region-set-us-east-1` | Switch to us-east-1 (N. Virginia) |
| `make region-set-us-east-2` | Switch to us-east-2 (Ohio) |
| `make frontend-install` | Install frontend dependencies |
| `make frontend-dev` | Run frontend dev server |
| `make frontend-build` | Build frontend for production |
| `make frontend-deploy` | Deploy frontend to S3/CloudFront |
| `make frontend-invalidate-cache` | Invalidate CloudFront cache |

---

## Troubleshooting

### EKS Node Group creation fails with quota error

**Error message:**
```
Error: waiting for EKS Node Group create: unexpected state 'CREATE_FAILED', wanted target 'ACTIVE'.
last error: AsgInstanceLaunchFailures: You've reached your quota for maximum Fleet Requests for this account.
```

**Cause:** Your AWS account has a quota limit on EC2 instances. New accounts often have low default limits.

**Solution:**

1. **Delete the failed node group** (it's stuck in a failed state and blocks new attempts):
   ```bash
   aws eks delete-nodegroup \
     --cluster-name carepath-demo-cluster \
     --nodegroup-name carepath-demo-cluster-node-group \
     --profile $DEPLOY_AWS_PROFILE \
     --region $DEPLOY_AWS_REGION
   ```

2. **Wait for deletion** (~2 minutes). Check status:
   ```bash
   aws eks list-nodegroups \
     --cluster-name carepath-demo-cluster \
     --profile $DEPLOY_AWS_PROFILE \
     --region $DEPLOY_AWS_REGION
   ```
   When it returns `{"nodegroups": []}`, proceed.

3. **Choose one of these options to resolve:**

   **Option A: Switch to SPOT instances** (recommended - quick fix)

   SPOT instances use a different AWS quota pool:
   ```bash
   make ec2-config-set-as-spot
   ```

   **Option B: Reduce node count** (if you want to stay on On-Demand)

   Edit `infra/terraform/envs/demo/variables.tf`:
   ```hcl
   node_desired_size = 1
   node_min_size     = 1
   node_max_size     = 3
   ```

   **Option C: Request quota increase** (takes time - hours to days)

   Go to [AWS Service Quotas](https://console.aws.amazon.com/servicequotas/home/services/ec2/quotas) and request an increase for "Running On-Demand Standard instances". For 3 t3.medium nodes, request at least 6 vCPUs.

   **Option D: Switch to a different region** (if you have quota approved elsewhere)

   If you have quota approved in another region (e.g., us-east-2), you can switch regions. This requires destroying existing infrastructure first. See [Configuration > AWS Region](#aws-region) for details.
   ```bash
   make tf-destroy
   make region-set-us-east-2
   make tf-apply
   ```

4. **Re-run Terraform:**
   ```bash
   make tf-apply
   ```

See [Configuration > EC2 Node Capacity Type](#ec2-node-capacity-type) for more details on SPOT vs On-Demand instances.

### Terraform init fails
- Verify `backend.hcl` exists: `ls infra/terraform/envs/demo/backend.hcl`
- Check AWS credentials: `make aws-login`

### EKS authentication issues
- Reconfigure kubectl: `make k8s-config`
- Verify IAM permissions

### Pod not starting
- Check logs: `make k8s-logs s=chat-api`
- Check events: `kubectl describe pod <pod-name> -n carepath-demo`
- Check image exists: `aws ecr describe-images --repository-name carepath-chat-api`

### MongoDB connection issues
- Verify your Atlas cluster allows connections from EKS node IPs (or has 0.0.0.0/0 for demo)
- Check connection string in secret: `kubectl get secret mongodb-secret -n carepath-demo -o yaml`
- Verify `mongodb_uri` in `terraform.tfvars` is correct

### LoadBalancer URL not available
- Wait 2-3 minutes after deployment
- Check service: `kubectl get svc chat-api-service -n carepath-demo`
- Check AWS console for ELB status

### Terraform state lock error

**Error message:**
```
Error: Error acquiring the state lock
Lock Info:
  ID:        6811ddc7-7e48-ed54-a727-...
  Operation: OperationTypeApply
```

**Cause:** A previous Terraform operation was interrupted (Ctrl+C, terminal closed, session timeout) before it could release the state lock. Terraform uses DynamoDB to prevent concurrent modifications.

**Solution:**

1. **Verify no other Terraform is running** - check for other terminals/processes
2. **Force-unlock the state** using the Lock ID from the error:
   ```bash
   cd infra/terraform/envs/demo
   source .env
   AWS_PROFILE=$DEPLOY_AWS_PROFILE AWS_REGION=$DEPLOY_AWS_REGION \
     terraform force-unlock -force <LOCK_ID>
   ```
3. **Retry your command:**
   ```bash
   make tf-apply
   ```

**Prevention:** Let Terraform operations complete fully. If you need to cancel, use Ctrl+C once and wait for graceful shutdown rather than force-killing.

---

## Teardown

To destroy all infrastructure:

```bash
make tf-destroy
```

**Warning:** This deletes all resources including MongoDB cluster. Data will be lost unless backups are enabled.

---

## Related Documentation

- [Infrastructure Operations](infra.md) - Day-to-day operations (logs, scaling, rollbacks) for deployed infrastructure
- [Rollout Options](deploy-rollout-options.md) - Deployment strategies (rolling, canary, blue-green)
- [AI Service Upgrade](../notes/issues/6-very-high/ai-service-upgrade.md) - Deploying with real LLM
- [Model Management](models.md) - LLM configuration
- [Infrastructure Guide](../infra/terraform/README.md) - Terraform details
