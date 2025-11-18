# Infrastructure Spec (Terraform, ECR, EKS, HPA, Deployment)

This file covers infra for deploying **service_db_api** and **service_chat** to AWS EKS using Docker and Terraform.

---

## 1. High-Level Components

- [ ] AWS networking:
  - [ ] VPC, subnets, internet gateway, NAT gateways, route tables

- [ ] AWS compute and container registry:
  - [ ] EKS cluster + managed node group
  - [ ] ECR repositories (one per service)

- [ ] Terraform state:
  - [ ] S3 bucket for remote state
  - [ ] DynamoDB table for state locking

- [ ] MongoDB:
  - [ ] MongoDB Atlas cluster + db user

- [ ] Kubernetes workloads:
  - [ ] Namespace for app
  - [ ] Deployments for `db-api` and `chat-api`
  - [ ] Services for both
  - [ ] HPA for autoscaling on CPU

---

## 2. Terraform Layout

- [ ] Create `infra/terraform/`:
  - [ ] `backend.tf` – S3 backend + DynamoDB lock
  - [ ] `providers.tf` – AWS, Kubernetes, Mongo Atlas providers

- [ ] Create modules:
  - [ ] `infra/terraform/modules/network/`
    - [ ] `main.tf`
    - [ ] `variables.tf`
    - [ ] `outputs.tf`
  - [ ] `infra/terraform/modules/eks/`
    - [ ] `main.tf`
    - [ ] `variables.tf`
    - [ ] `outputs.tf`
  - [ ] `infra/terraform/modules/ecr/`
    - [ ] `main.tf`
    - [ ] `outputs.tf`
  - [ ] `infra/terraform/modules/mongo_atlas/`
    - [ ] `main.tf`
    - [ ] `variables.tf`
    - [ ] `outputs.tf`
  - [ ] `infra/terraform/modules/app/`
    - [ ] `main.tf`
    - [ ] `variables.tf`
    - [ ] `outputs.tf`

- [ ] Create environment config:
  - [ ] `infra/terraform/envs/demo/main.tf`
  - [ ] `infra/terraform/envs/demo/variables.tf`
  - [ ] `infra/terraform/envs/demo/outputs.tf`
  - [ ] `infra/terraform/envs/demo/terraform.tfvars`

---

## 3. ECR Module

- [ ] In `modules/ecr/main.tf`:
  - [ ] Create `aws_ecr_repository` for:
    - [ ] `carepath-db-api`
    - [ ] `carepath-chat-api`
  - [ ] Optionally add lifecycle policy (keep last N images)

- [ ] In `modules/ecr/outputs.tf`:
  - [ ] Output:
    - [ ] `db_api_repo_url`
    - [ ] `chat_api_repo_url`

---

## 4. App Module (Kubernetes Manifests via Terraform)

In `modules/app/main.tf`:

- [ ] Create `kubernetes_namespace`:
  - [ ] Name: e.g. `carepath-demo`

### 4.1 db-api Deployment + Service

- [ ] Create `kubernetes_deployment` for `db-api`:
  - [ ] Use `var.db_api_image` (ECR URI + tag)
  - [ ] Replicas: 3
  - [ ] Env:
    - [ ] `MONGODB_URI` from Secret
    - [ ] `MONGODB_DB_NAME`
  - [ ] Resource requests/limits:
    - [ ] Requests: `cpu: 100m`, `memory: 256Mi`
    - [ ] Limits: `cpu: 500m`, `memory: 512Mi`
  - [ ] Liveness and readiness probes hitting `/health`

- [ ] Create `kubernetes_service` for db-api:
  - [ ] Type: `ClusterIP`
  - [ ] Port: 8001
  - [ ] Name: `db-api-service`

### 4.2 chat-api Deployment + Service

- [ ] Create `kubernetes_deployment` for `chat-api`:
  - [ ] Use `var.chat_api_image`
  - [ ] Replicas: 3
  - [ ] Env:
    - [ ] `DB_API_BASE_URL=http://db-api-service.carepath-demo.svc.cluster.local:8001`
    - [ ] `LLM_MODE=mock`
    - [ ] `VECTOR_MODE=mock`
    - [ ] Pinecone env vars (API key, env, index) from Secret
  - [ ] Resource requests/limits similar to db-api
  - [ ] Liveness/readiness probes on `/health`

- [ ] Create `kubernetes_service` for chat-api:
  - [ ] Type: `LoadBalancer` (for demo)
  - [ ] Port: 80 targeting container port 8002
  - [ ] Name: `chat-api-service`

---

## 5. HPA (Autoscaling)

- [ ] For each Deployment, define `kubernetes_horizontal_pod_autoscaler`:
  - [ ] Target resource: `db-api` deployment
    - [ ] min_replicas: 3
    - [ ] max_replicas: 6
    - [ ] target CPU utilization: 60%
  - [ ] Target resource: `chat-api` deployment
    - [ ] same CPU-based policy

- [ ] In `eks` module:
  - [ ] Configure node group auto-scaling constraints to support pod HPA
    - [ ] min_size, max_size with sensible bounds

---

## 6. MongoDB Atlas Module

- [ ] In `modules/mongo_atlas/main.tf`:
  - [ ] Create Mongo Atlas cluster (M10 / free tier for demo)
  - [ ] Create database user with limited permissions

- [ ] In `modules/mongo_atlas/outputs.tf`:
  - [ ] Output `mongodb_connection_string` for application use

- [ ] In `modules/app/main.tf`:
  - [ ] Create Kubernetes Secret with `MONGODB_URI` from output

---

## 7. Makefile Targets (Infra & Deploy)

At repo root, implement:

- [ ] `make tf-init`:
  - [ ] `cd infra/terraform/envs/demo && terraform init`

- [ ] `make tf-plan`:
  - [ ] `cd infra/terraform/envs/demo && terraform plan`

- [ ] `make tf-apply`:
  - [ ] `cd infra/terraform/envs/demo && terraform apply`

- [ ] `make tf-destroy`:
  - [ ] `cd infra/terraform/envs/demo && terraform destroy`

Build & push images:

- [ ] `make docker-build-db-api`:
  - [ ] Build using `service_db_api/Dockerfile`
- [ ] `make docker-build-chat`:
  - [ ] Build using `service_chat/Dockerfile`

- [ ] `make docker-push-db-api`:
  - [ ] Tag and push to `carepath-db-api` ECR repo
- [ ] `make docker-push-chat`:
  - [ ] Tag and push to `carepath-chat-api` ECR repo

Deploy:

- [ ] `make deploy-db-api`:
  - [ ] Build, push, update `var.db_api_image`, run partial `terraform apply` for app module

- [ ] `make deploy-chat`:
  - [ ] Build, push, update `var.chat_api_image`, run partial `terraform apply` for app module

- [ ] `make deploy-all`:
  - [ ] Build & push both images
  - [ ] Run full `terraform apply` for demo environment

---

## 8. Dockerfiles

- [ ] `service_db_api/Dockerfile`:
  - [ ] Base image: `python:3.11-slim`
  - [ ] Install dependencies
  - [ ] Copy `service_db_api/` code
  - [ ] Set `CMD` to `uvicorn service_db_api.main:app --host 0.0.0.0 --port 8001`

- [ ] `service_chat/Dockerfile`:
  - [ ] Base image: `python:3.11-slim`
  - [ ] Install dependencies
  - [ ] Copy `service_chat/` code
  - [ ] Set `CMD` to `uvicorn service_chat.main:app --host 0.0.0.0 --port 8002`

---

## 9. Deployment Order & Smoke Tests

- [ ] Build and push images for both services
- [ ] Run `make tf-apply` for demo env
- [ ] Verify in cluster:
  - [ ] `kubectl get pods -n carepath-demo`
  - [ ] Ensure `db-api` and `chat-api` pods are Running
- [ ] Test endpoints:
  - [ ] `/health` on both services
  - [ ] `/triage` via LoadBalancer/Ingress hostname
