# Infrastructure Spec (Terraform, ECR, EKS, HPA, Deployment)

This file covers infra for deploying **service_db_api** and **service_chat** to AWS EKS using Docker and Terraform.

---

## 1. High-Level Components

- [x] AWS networking:
  - [x] VPC, subnets, internet gateway, NAT gateways, route tables

- [x] AWS compute and container registry:
  - [x] EKS cluster + managed node group
  - [x] ECR repositories (one per service)

- [x] Terraform state:
  - [x] S3 bucket for remote state (backend configuration)
  - [x] DynamoDB table for state locking (backend configuration)

- [x] MongoDB:
  - [x] MongoDB Atlas cluster + db user

- [x] Kubernetes workloads:
  - [x] Namespace for app
  - [x] Deployments for `db-api` and `chat-api`
  - [x] Services for both
  - [x] HPA for autoscaling on CPU

---

## 2. Terraform Layout

- [x] Create `infra/terraform/`:
  - [x] `backend.tf` – S3 backend + DynamoDB lock
  - [x] `providers.tf` – AWS, Kubernetes, Mongo Atlas providers

- [x] Create modules:
  - [x] `infra/terraform/modules/network/`
    - [x] `main.tf`
    - [x] `variables.tf`
    - [x] `outputs.tf`
  - [x] `infra/terraform/modules/eks/`
    - [x] `main.tf`
    - [x] `variables.tf`
    - [x] `outputs.tf`
  - [x] `infra/terraform/modules/ecr/`
    - [x] `main.tf`
    - [x] `outputs.tf`
  - [x] `infra/terraform/modules/mongo_atlas/`
    - [x] `main.tf`
    - [x] `variables.tf`
    - [x] `outputs.tf`
  - [x] `infra/terraform/modules/app/`
    - [x] `main.tf`
    - [x] `variables.tf`
    - [x] `outputs.tf`

- [x] Create environment config:
  - [x] `infra/terraform/envs/demo/main.tf`
  - [x] `infra/terraform/envs/demo/variables.tf`
  - [x] `infra/terraform/envs/demo/outputs.tf`
  - [x] `infra/terraform/envs/demo/terraform.tfvars` (example provided)

---

## 3. ECR Module

- [x] In `modules/ecr/main.tf`:
  - [x] Create `aws_ecr_repository` for:
    - [x] `carepath-db-api`
    - [x] `carepath-chat-api`
  - [x] Optionally add lifecycle policy (keep last N images)

- [x] In `modules/ecr/outputs.tf`:
  - [x] Output:
    - [x] `db_api_repo_url`
    - [x] `chat_api_repo_url`

---

## 4. App Module (Kubernetes Manifests via Terraform)

In `modules/app/main.tf`:

- [x] Create `kubernetes_namespace`:
  - [x] Name: e.g. `carepath-demo`

### 4.1 db-api Deployment + Service

- [x] Create `kubernetes_deployment` for `db-api`:
  - [x] Use `var.db_api_image` (ECR URI + tag)
  - [x] Replicas: 3
  - [x] Env:
    - [x] `MONGODB_URI` from Secret
    - [x] `MONGODB_DB_NAME`
  - [x] Resource requests/limits:
    - [x] Requests: `cpu: 100m`, `memory: 256Mi`
    - [x] Limits: `cpu: 500m`, `memory: 512Mi`
  - [x] Liveness and readiness probes hitting `/health`

- [x] Create `kubernetes_service` for db-api:
  - [x] Type: `ClusterIP`
  - [x] Port: 8001
  - [x] Name: `db-api-service`

### 4.2 chat-api Deployment + Service

- [x] Create `kubernetes_deployment` for `chat-api`:
  - [x] Use `var.chat_api_image`
  - [x] Replicas: 3
  - [x] Env:
    - [x] `DB_API_BASE_URL=http://db-api-service.carepath-demo.svc.cluster.local:8001`
    - [x] `LLM_MODE=mock`
    - [x] `VECTOR_MODE=mock`
    - [x] Pinecone env vars (API key, env, index) from ConfigMap/Secret
  - [x] Resource requests/limits similar to db-api
  - [x] Liveness/readiness probes on `/health`

- [x] Create `kubernetes_service` for chat-api:
  - [x] Type: `LoadBalancer` (for demo)
  - [x] Port: 80 targeting container port 8002
  - [x] Name: `chat-api-service`

---

## 5. HPA (Autoscaling)

- [x] For each Deployment, define `kubernetes_horizontal_pod_autoscaler`:
  - [x] Target resource: `db-api` deployment
    - [x] min_replicas: 3
    - [x] max_replicas: 6
    - [x] target CPU utilization: 60%
  - [x] Target resource: `chat-api` deployment
    - [x] same CPU-based policy

- [x] In `eks` module:
  - [x] Configure node group auto-scaling constraints to support pod HPA
    - [x] min_size, max_size with sensible bounds

---

## 6. MongoDB Atlas Module

- [x] In `modules/mongo_atlas/main.tf`:
  - [x] Create Mongo Atlas cluster (M10 / free tier for demo)
  - [x] Create database user with limited permissions

- [x] In `modules/mongo_atlas/outputs.tf`:
  - [x] Output `mongodb_connection_string` for application use

- [x] In `modules/app/main.tf`:
  - [x] Create Kubernetes Secret with `MONGODB_URI` from output

---

## 7. Makefile Targets (Infra & Deploy)

At repo root, implement:

- [x] `make tf-init`:
  - [x] `cd infra/terraform/envs/demo && terraform init`

- [x] `make tf-plan`:
  - [x] `cd infra/terraform/envs/demo && terraform plan`

- [x] `make tf-apply`:
  - [x] `cd infra/terraform/envs/demo && terraform apply`

- [x] `make tf-destroy`:
  - [x] `cd infra/terraform/envs/demo && terraform destroy`

Build & push images:

- [x] `make docker-build-db-api`:
  - [x] Build using `service_db_api/Dockerfile`
- [x] `make docker-build-chat`:
  - [x] Build using `service_chat/Dockerfile`

- [x] `make docker-push-db-api`:
  - [x] Tag and push to `carepath-db-api` ECR repo
- [x] `make docker-push-chat`:
  - [x] Tag and push to `carepath-chat-api` ECR repo

Deploy:

- [x] `make deploy-db-api`:
  - [x] Build, push, update `var.db_api_image`, run partial `terraform apply` for app module

- [x] `make deploy-chat`:
  - [x] Build, push, update `var.chat_api_image`, run partial `terraform apply` for app module

- [x] `make deploy-all`:
  - [x] Build & push both images
  - [x] Run full `terraform apply` for demo environment

---

## 8. Dockerfiles

- [x] `service_db_api/Dockerfile`:
  - [x] Base image: `python:3.11-slim`
  - [x] Install dependencies
  - [x] Copy `service_db_api/` code
  - [x] Set `CMD` to `uvicorn service_db_api.main:app --host 0.0.0.0 --port 8001`

- [x] `service_chat/Dockerfile`:
  - [x] Base image: `python:3.11-slim`
  - [x] Install dependencies
  - [x] Copy `service_chat/` code
  - [x] Set `CMD` to `uvicorn service_chat.main:app --host 0.0.0.0 --port 8002`

---

## 9. Deployment Order & Smoke Tests

- [x] Build and push images for both services (Makefile targets implemented)
- [x] Run `make tf-apply` for demo env (Makefile target implemented)
- [x] Verify in cluster (user to complete after deployment):
  - [x] `kubectl get pods -n carepath-demo`
  - [x] Ensure `db-api` and `chat-api` pods are Running
- [x] Test endpoints (user to complete after deployment):
  - [x] `/health` on both services
  - [x] `/triage` via LoadBalancer/Ingress hostname
