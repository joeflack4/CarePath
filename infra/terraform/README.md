# CarePath Infrastructure

This directory contains Terraform code for deploying CarePath AI to AWS EKS.

## Architecture

The infrastructure consists of:
- **VPC**: Multi-AZ network with public and private subnets
- **EKS Cluster**: Managed Kubernetes cluster with autoscaling node groups
- **ECR Repositories**: Container registries for db-api and chat-api services
- **MongoDB Atlas**: Managed MongoDB database
- **Kubernetes Resources**: Deployments, Services, HPAs, Secrets, and ConfigMaps

## Prerequisites

Before deploying, ensure you have:

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.5.0 installed
3. **Docker** installed for building images
4. **kubectl** installed for cluster management
5. **MongoDB Atlas account** with API keys
6. `.env`: Ensure that `MONGODB_URI` is set to your cloud deployment (e.g. MongoDB Atlas, rather than local)

## Setup Instructions

### 1. Configure Backend

Create `infra/terraform/envs/demo/backend.hcl` from the example:

```bash
cp infra/terraform/envs/demo/backend.hcl.example infra/terraform/envs/demo/backend.hcl
```

Edit `backend.hcl` with your S3 bucket and DynamoDB table for state management:

```hcl
bucket         = "your-terraform-state-bucket"
key            = "carepath/demo/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "your-terraform-lock-table"
```

> **Note**: You must create the S3 bucket and DynamoDB table manually before running Terraform.

### 2. Configure Variables

Create `infra/terraform/envs/demo/terraform.tfvars` from the example:

```bash
cp infra/terraform/envs/demo/terraform.tfvars.example infra/terraform/envs/demo/terraform.tfvars
```

Edit `terraform.tfvars` with your actual values:

```hcl
environment = "demo"
aws_region  = "us-east-1"

# MongoDB Atlas
mongodb_atlas_org_id      = "your-org-id"
mongodb_atlas_public_key  = "your-public-key"
mongodb_atlas_private_key = "your-private-key"
mongodb_username          = "carepath_admin"
mongodb_password          = "your-secure-password"

# Docker Images (update after first deployment)
db_api_image   = "123456789012.dkr.ecr.us-east-1.amazonaws.com/carepath-db-api:latest"
chat_api_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/carepath-chat-api:latest"
```

### 3. Deploy Infrastructure

From the project root:

```bash
# 1. Authenticate with AWS
make aws-login

# 2. Initialize Terraform
make tf-init

# 3. Review the plan
make tf-plan

# 4. Apply infrastructure
make tf-apply
```

This will create:
- VPC with public/private subnets across 2 AZs
- EKS cluster with managed node group
- ECR repositories for both services
- MongoDB Atlas cluster
- Kubernetes namespace, deployments, services, and HPAs

### 4. Build and Push Docker Images

```bash
# Build images locally
make docker-build-db-api
make docker-build-chat

# Push to ECR (requires Terraform to be applied first)
make docker-push-db-api
make docker-push-chat
```

### 5. Deploy Applications

After building and pushing images, update the image URLs in `terraform.tfvars` and reapply:

```bash
make tf-apply
```

Or use the deploy targets to build, push, and deploy in one step:

```bash
# Deploy both services
make deploy-all

# Or deploy individually
make deploy-db-api
make deploy-chat
```

### 6. Access the Cluster

Configure kubectl to access your cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name carepath-demo-cluster
```

Verify pods are running:

```bash
kubectl get pods -n carepath-demo
kubectl get services -n carepath-demo
```

Get the LoadBalancer URL for the chat API:

```bash
kubectl get service chat-api-service -n carepath-demo
```

## Terraform Modules

### Network Module
- Creates VPC, subnets, NAT gateways, internet gateway
- Configures route tables for public and private subnets
- Tags subnets for EKS load balancer integration

### EKS Module
- Creates EKS cluster with managed node group
- Configures IAM roles for cluster and nodes
- Sets up OIDC provider for service accounts

### ECR Module
- Creates ECR repositories for both services
- Configures lifecycle policies to retain last 10 images
- Enables image scanning on push

### MongoDB Atlas Module
- Creates MongoDB Atlas project and cluster
- Configures database user with read/write permissions
- Sets up IP whitelist for EKS nodes

### App Module
- Creates Kubernetes namespace
- Deploys db-api and chat-api services
- Configures Secrets and ConfigMaps
- Sets up HPA for autoscaling (3-6 replicas)
- Exposes chat-api via LoadBalancer

## Environment Variables

The following environment variables are used:

### From .env file (loaded by Makefile):
- `DEPLOY_AWS_PROFILE` - AWS profile for deployment
- `DEPLOY_AWS_REGION` - AWS region

### In Kubernetes (via ConfigMap/Secret):
- `MONGODB_URI` - MongoDB connection string (Secret)
- `MONGODB_DB_NAME` - Database name
- `DB_API_BASE_URL` - Internal URL to db-api service
- `LLM_MODE` - LLM mode (mock/qwen)
- `VECTOR_MODE` - Vector DB mode (mock/pinecone)
- `LOG_LEVEL` - Application log level

## Cleanup

To destroy all infrastructure:

```bash
make tf-destroy
```

> **Warning**: This will delete all resources including the MongoDB cluster and data.

## Troubleshooting

### ECR Push Fails
Ensure you're authenticated to ECR:
```bash
make ecr-login
```

### Pods Not Starting
Check pod logs:
```bash
kubectl logs -n carepath-demo <pod-name>
kubectl describe pod -n carepath-demo <pod-name>
```

### HPA Not Scaling
Check HPA status:
```bash
kubectl get hpa -n carepath-demo
kubectl describe hpa -n carepath-demo db-api-hpa
```

Ensure metrics-server is installed in your cluster.

### MongoDB Connection Issues
Verify the MongoDB cluster is accessible:
- Check MongoDB Atlas IP whitelist includes EKS NAT gateway IPs
- Verify credentials in Kubernetes secret:
  ```bash
  kubectl get secret mongodb-secret -n carepath-demo -o yaml
  ```

## Cost Optimization

For demo/dev environments:
- Use smaller EKS node instances (t3.medium)
- Reduce HPA max replicas
- Use MongoDB Atlas M10 tier (or shared tier for testing)
- Destroy infrastructure when not in use

## Next Steps

After deployment:
1. Test the health endpoints
2. Load synthetic data into MongoDB
3. Test the /triage endpoint
4. Configure monitoring and logging
5. Set up CI/CD pipelines

See the main project README for testing instructions.
