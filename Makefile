.PHONY: help install-db-api install-chat run-db-api run-chat load-synthetic generate-synthetic download-llm-model \
install-chat-llm test-triage docker-build-db-api docker-build-chat docker-push-db-api docker-push-chat ecr-login \
aws-login tf-login tf-init tf-plan tf-apply tf-destroy deploy-db-api deploy-chat deploy-all mongo-local-start-macos \
mongo-local-install-macos k8s-config k8s-status k8s-get-urls k8s-logs k8s-pods-list k8s-scale-up k8s-scale-down \
k8s-rollback-db-api k8s-rollback-chat k8s-rollback-all k8s-restart-db-api k8s-restart-chat k8s-history \
ec2-config-set-as-nodes ec2-config-set-as-spot ec2-config-status region-set-us-east-1 region-set-us-east-2 \
region-status docker-push-all test-triage-cloud test-triage-local

# Default target
help:
	@echo "CarePath AI - Available Make Targets"
	@echo ""
	@echo "Development:"
	@echo "  make install-db-api      - Install dependencies for service_db_api"
	@echo "  make install-chat        - Install dependencies for service_chat"
	@echo "  make install-chat-llm    - Install LLM dependencies for service_chat"
	@echo "  make run-db-api          - Run db API locally with uvicorn"
	@echo "  make run-chat            - Run chat API locally with uvicorn"
	@echo "  make generate-synthetic  - Generate synthetic data files"
	@echo "  make load-synthetic      - Load synthetic data into MongoDB"
	@echo "  make download-llm-model  - Download Qwen3-4B-Thinking-2507 model"
	@echo "  make test-triage         - Test the /triage endpoint (requires services running)"
	@echo "                             Usage: make test-triage m='your question here'"
	@echo ""
	@echo "Docker / Build:"
	@echo "  make docker-build-db-api - Build Docker image for db-api"
	@echo "  make docker-build-chat   - Build Docker image for chat-api"
	@echo "  make ecr-login           - Log in to AWS ECR"
	@echo "  make docker-push-db-api  - Push db-api image to ECR"
	@echo "  make docker-push-chat    - Push chat-api image to ECR"
	@echo ""
	@echo "Infrastructure:"
	@echo "  make tf-init             - Initialize Terraform"
	@echo "  make tf-plan             - Plan Terraform changes"
	@echo "  make tf-apply            - Apply Terraform changes"
	@echo "  make tf-destroy          - Destroy Terraform resources"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy-db-api       - Deploy db-api service"
	@echo "  make deploy-chat         - Deploy chat service"
	@echo "  make deploy-all          - Deploy all services"
	@echo ""
	@echo "Kubernetes Operations:"
	@echo "  make k8s-config          - Configure kubectl for EKS cluster"
	@echo "  make k8s-status          - Show deployment status"
	@echo "  make k8s-get-urls        - Get service URLs"
	@echo "  make k8s-pods-list            - List all pods"
	@echo "  make k8s-logs s=SERVICE  - View logs (s=db-api or s=chat-api)"
	@echo ""
	@echo "Scaling:"
	@echo "  make k8s-scale-up s=SERVICE r=N   - Scale up (s=db-api|chat-api, r=replicas)"
	@echo "  make k8s-scale-down s=SERVICE r=N - Scale down"
	@echo ""
	@echo "Rollback:"
	@echo "  make k8s-rollback-db-api - Rollback db-api to previous version"
	@echo "  make k8s-rollback-chat   - Rollback chat-api to previous version"
	@echo "  make k8s-restart-db-api  - Restart db-api pods"
	@echo "  make k8s-restart-chat    - Restart chat-api pods"
	@echo "  make k8s-history         - View rollout history for all services"
	@echo ""
	@echo "EC2 Configuration:"
	@echo "  make ec2-config-status       - Show current EC2 node capacity type"
	@echo "  make ec2-config-set-as-nodes - Use ON_DEMAND (standard) EC2 instances"
	@echo "  make ec2-config-set-as-spot  - Use SPOT instances (cheaper, different quota)"
	@echo ""
	@echo "Region Configuration:"
	@echo "  make region-status           - Show current AWS region"
	@echo "  make region-set-us-east-1    - Switch to us-east-1 (N. Virginia)"
	@echo "  make region-set-us-east-2    - Switch to us-east-2 (Ohio)"

ifneq (,$(wildcard .env))
include .env
export  # export included vars to child processes
endif

# https://tinyurl.com/flack-bwell-demo-api
DEMO_CHAT_SERVICE_URL=http://ae650096299bf4232b4e4b1df1ac3901-1174130703.us-east-2.elb.amazonaws.com

# Development targets
install-db-api:
	@echo "Installing dependencies for service_db_api..."
	pip install fastapi uvicorn motor pymongo pydantic-settings

install-chat:
	@echo "Installing dependencies for service_chat..."
	pip install fastapi uvicorn httpx pydantic-settings

install-chat-llm:
	@echo "Installing LLM dependencies for service_chat..."
	pip install torch transformers huggingface-hub

run-db-api:
	@echo "Starting service_db_api on port 8001..."
	uvicorn service_db_api.main:app --reload --port 8001

run-chat:
	@echo "Starting service_chat on port 8002..."
	uvicorn service_chat.main:app --reload --port 8002

generate-synthetic:
	@echo "Generating synthetic data files..."
	python scripts/generate_synthetic_data.py

load-synthetic:
	@echo "Loading synthetic data into MongoDB..."
	python scripts/load_synthetic_data.py --drop

download-llm-model:
	@echo "Downloading Qwen3-4B-Thinking-2507 model from Hugging Face..."
	@python -c "from service_chat.services.model_manager import download_model_if_needed; download_model_if_needed()"
	@echo "✅ Model downloaded successfully"

test-triage-local:
	@echo "Testing /triage endpoint..."
	@curl -s -X POST http://localhost:8002/triage \
		-H "Content-Type: application/json" \
		-d '{"patient_mrn": "P000123", "query": "$(if $(m),$(m),What are my current medications?)"}' | python -m json.tool
	@echo ""
	@echo "✅ Test complete"

test-triage-cloud:
	@echo "Testing /triage endpoint..."
	@curl -s -X POST $(DEMO_CHAT_SERVICE_URL)/triage \
		-H "Content-Type: application/json" \
		-d '{"patient_mrn": "P000123", "query": "$(if $(m),$(m),What are my current medications?)"}' | python -m json.tool
	@echo ""
	@echo "✅ Test complete"

test-triage: test-triage-cloud

mongo-local-install-macos:
	brew tap mongodb/brew
	brew install mongodb-community@7.0

mongo-local-start-macos:
	brew services start mongodb-community@7.0

# Docker / Build targets
# Get ECR URLs from Terraform outputs
ECR_DB_API_URL := $(shell cd infra/terraform/envs/demo && AWS_PROFILE=$(DEPLOY_AWS_PROFILE) terraform output -raw db_api_repo_url 2>/dev/null || echo "")
ECR_CHAT_API_URL := $(shell cd infra/terraform/envs/demo && AWS_PROFILE=$(DEPLOY_AWS_PROFILE) terraform output -raw chat_api_repo_url 2>/dev/null || echo "")
AWS_ACCOUNT_ID := $(DEPLOY_AWS_ACCOUNT_ID)
AWS_REGION := $(DEPLOY_AWS_REGION)

docker-build-db-api:
	@echo "Building Docker image for db-api (linux/amd64)..."
	docker build --platform linux/amd64 -t carepath-db-api:latest -f service_db_api/Dockerfile service_db_api/

docker-build-chat:
	@echo "Building Docker image for chat-api (linux/amd64)..."
	docker build --platform linux/amd64 -t carepath-chat-api:latest -f service_chat/Dockerfile service_chat/

ecr-login:
	@echo "Logging into ECR..."
	aws ecr get-login-password --region $(AWS_REGION) --profile $(DEPLOY_AWS_PROFILE) | \
		docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

docker-push-db-api: ecr-login
	@echo "Tagging and pushing db-api image to ECR..."
	@if [ -z "$(ECR_DB_API_URL)" ]; then \
		echo "Error: ECR URL not found. Run 'make tf-apply' first."; \
		exit 1; \
	fi
	docker tag carepath-db-api:latest $(ECR_DB_API_URL):latest
	docker push $(ECR_DB_API_URL):latest
	@echo "✅ db-api image pushed to $(ECR_DB_API_URL):latest"

docker-push-chat: ecr-login
	@echo "Tagging and pushing chat-api image to ECR..."
	@if [ -z "$(ECR_CHAT_API_URL)" ]; then \
		echo "Error: ECR URL not found. Run 'make tf-apply' first."; \
		exit 1; \
	fi
	docker tag carepath-chat-api:latest $(ECR_CHAT_API_URL):latest
	docker push $(ECR_CHAT_API_URL):latest
	@echo "✅ chat-api image pushed to $(ECR_CHAT_API_URL):latest"

docker-push-all: docker-push-db-api docker-push-chat

# Infrastructure targets (to be implemented)
# Login
# This goal is used to make sure your local CLI session is authenticated
# with AWS via SSO before running Terraform or other AWS CLI commands.
# `aws sts get-caller-identity` is a diagnostic command — it prints
# the current authenticated AWS account ID, user ARN, and user ID.
# If this succeeds, Terraform will also have valid credentials.
aws-login:
#	@echo ">>> Logging in with AWS SSO for profile: $(DEPLOY_AWS_PROFILE)"
#	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) AWS_SDK_LOAD_CONFIG=1 \
#		aws sso login
	@echo ">>> Verifying AWS identity..."
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) AWS_SDK_LOAD_CONFIG=1 \
		aws sso login --profile $(DEPLOY_AWS_PROFILE)
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) AWS_SDK_LOAD_CONFIG=1 \
		aws sts get-caller-identity  --profile $(DEPLOY_AWS_PROFILE)
	@echo "✅ Login complete — credentials are valid."

tf-login: aws-login

tf-init:
	@echo "Initializing Terraform..."
	cd infra/terraform/envs/demo && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform init -backend-config=backend.hcl

tf-plan:
	@echo "Planning Terraform changes..."
	cd infra/terraform/envs/demo && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform plan

tf-apply:
	@echo "Applying Terraform changes..."
	cd infra/terraform/envs/demo && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform apply

tf-destroy:
	@echo "Destroying Terraform resources..."
	cd infra/terraform/envs/demo && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform destroy

# Deployment targets
deploy-db-api: docker-build-db-api docker-push-db-api
	@echo "Deploying db-api..."
	@echo "Updating Terraform with new image..."
	cd infra/terraform/envs/demo && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform apply -target=module.app.kubernetes_deployment.db_api -auto-approve
	@echo "✅ db-api deployed successfully"

deploy-chat: docker-build-chat docker-push-chat
	@echo "Deploying chat-api..."
	@echo "Updating Terraform with new image..."
	cd infra/terraform/envs/demo && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform apply -target=module.app.kubernetes_deployment.chat_api -auto-approve
	@echo "✅ chat-api deployed successfully"

deploy-all: docker-build-db-api docker-build-chat docker-push-db-api docker-push-chat
	@echo "Deploying all services..."
	@echo "Running full Terraform apply..."
	cd infra/terraform/envs/demo && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform apply
	@echo "✅ All services deployed successfully"

## One-time deploy commands
DEPLOY_TF_BOOTSTRAP_DIR := infra/bootstrap

tf-bootstrap-init:
	cd $(DEPLOY_TF_BOOTSTRAP_DIR) && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform init

tf-bootstrap-apply:
	cd $(DEPLOY_TF_BOOTSTRAP_DIR) && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform apply -auto-approve \
	  -var="state_bucket_name=$(DEPLOY_TF_STATE_BUCKET_NAME)" \
	  -var="dynamodb_table_name=$(DEPLOY_TF_DYNAMO_DB_TABLE)" \
	  -var="region=$(DEPLOY_AWS_REGION)"

tf-bootstrap-destroy:
	cd $(DEPLOY_TF_BOOTSTRAP_DIR) && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform destroy -auto-approve \
	  -var="state_bucket_name=$(DEPLOY_TF_STATE_BUCKET_NAME)" \
	  -var="dynamodb_table_name=$(DEPLOY_TF_DYNAMO_DB_TABLE)" \
	  -var="region=$(DEPLOY_AWS_REGION)"

# Kubernetes Operations
K8S_NAMESPACE := carepath-demo
K8S_CLUSTER_NAME := carepath-demo-cluster

k8s-config:
	@echo "Configuring kubectl for EKS cluster..."
	aws eks update-kubeconfig --region $(DEPLOY_AWS_REGION) --name $(K8S_CLUSTER_NAME) --profile $(DEPLOY_AWS_PROFILE)
	@echo "✅ kubectl configured for $(K8S_CLUSTER_NAME)"

k8s-status:
	@echo "=== Deployments ==="
	kubectl get deployments -n $(K8S_NAMESPACE)
	@echo ""
	@echo "=== Pods ==="
	kubectl get pods -n $(K8S_NAMESPACE)
	@echo ""
	@echo "=== Services ==="
	kubectl get services -n $(K8S_NAMESPACE)
	@echo ""
	@echo "=== HPA ==="
	kubectl get hpa -n $(K8S_NAMESPACE)

k8s-get-urls:
	@echo "=== Service URLs ==="
	@echo ""
	@echo "Chat API (External LoadBalancer):"
	@kubectl get svc chat-api-service -n $(K8S_NAMESPACE) -o jsonpath='  URL: http://{.status.loadBalancer.ingress[0].hostname}{"\n"}' 2>/dev/null || echo "  (not yet available - LoadBalancer provisioning)"
	@echo ""
	@echo "DB API (Internal ClusterIP - not externally accessible):"
	@kubectl get svc db-api-service -n $(K8S_NAMESPACE) -o jsonpath='  Internal: {.spec.clusterIP}:{.spec.ports[0].port}{"\n"}' 2>/dev/null || echo "  (not available)"

k8s-pods-list:
	kubectl get pods -n $(K8S_NAMESPACE) -o wide

k8s-logs:
	@if [ -z "$(s)" ]; then \
		echo "Usage: make k8s-logs s=SERVICE"; \
		echo "  SERVICE: db-api or chat-api"; \
		exit 1; \
	fi
	kubectl logs -l app=$(s) -n $(K8S_NAMESPACE) --tail=100 -f

# Scaling commands
k8s-scale-up:
	@if [ -z "$(s)" ] || [ -z "$(r)" ]; then \
		echo "Usage: make k8s-scale-up s=SERVICE r=REPLICAS"; \
		echo "  SERVICE: db-api or chat-api"; \
		echo "  REPLICAS: number of replicas (e.g., 3)"; \
		exit 1; \
	fi
	@echo "Scaling $(s) to $(r) replicas..."
	kubectl scale deployment $(s) -n $(K8S_NAMESPACE) --replicas=$(r)
	@echo "✅ Scaled $(s) to $(r) replicas"
	kubectl get deployment $(s) -n $(K8S_NAMESPACE)

k8s-scale-down:
	@if [ -z "$(s)" ] || [ -z "$(r)" ]; then \
		echo "Usage: make k8s-scale-down s=SERVICE r=REPLICAS"; \
		echo "  SERVICE: db-api or chat-api"; \
		echo "  REPLICAS: number of replicas (e.g., 1)"; \
		exit 1; \
	fi
	@echo "Scaling $(s) down to $(r) replicas..."
	kubectl scale deployment $(s) -n $(K8S_NAMESPACE) --replicas=$(r)
	@echo "✅ Scaled $(s) to $(r) replicas"
	kubectl get deployment $(s) -n $(K8S_NAMESPACE)

# Rollback commands
k8s-rollback-db-api:
	@echo "Rolling back db-api to previous version..."
	kubectl rollout undo deployment/db-api -n $(K8S_NAMESPACE)
	@echo "Waiting for rollout to complete..."
	kubectl rollout status deployment/db-api -n $(K8S_NAMESPACE)
	@echo "✅ db-api rolled back successfully"

k8s-rollback-chat:
	@echo "Rolling back chat-api to previous version..."
	kubectl rollout undo deployment/chat-api -n $(K8S_NAMESPACE)
	@echo "Waiting for rollout to complete..."
	kubectl rollout status deployment/chat-api -n $(K8S_NAMESPACE)
	@echo "✅ chat-api rolled back successfully"

k8s-rollback-all: k8s-rollback-db-api k8s-rollback-chat

# Restart commands (rolling restart without changing image)
k8s-restart-db-api:
	@echo "Restarting db-api pods..."
	kubectl rollout restart deployment/db-api -n $(K8S_NAMESPACE)
	kubectl rollout status deployment/db-api -n $(K8S_NAMESPACE)
	@echo "✅ db-api restarted"

k8s-restart-chat:
	@echo "Restarting chat-api pods..."
	kubectl rollout restart deployment/chat-api -n $(K8S_NAMESPACE)
	kubectl rollout status deployment/chat-api -n $(K8S_NAMESPACE)
	@echo "✅ chat-api restarted"

# Rollout history
k8s-history:
	@echo "=== db-api rollout history ==="
	kubectl rollout history deployment/db-api -n $(K8S_NAMESPACE)
	@echo ""
	@echo "=== chat-api rollout history ==="
	kubectl rollout history deployment/chat-api -n $(K8S_NAMESPACE)

# EC2 Node Configuration
# These commands toggle between ON_DEMAND (standard) and SPOT instances
# SPOT instances use a different AWS quota pool and are useful when On-Demand quota is exhausted
TFVARS_FILE := infra/terraform/envs/demo/terraform.tfvars

ec2-config-set-as-nodes:
	@echo "Setting EC2 capacity type to ON_DEMAND (standard nodes)..."
	@sed -i.bak 's/^node_capacity_type = "SPOT"/node_capacity_type = "ON_DEMAND"/' $(TFVARS_FILE)
	@rm -f $(TFVARS_FILE).bak
	@echo "✅ EC2 capacity type set to ON_DEMAND"
	@echo "   Run 'make tf-apply' to apply changes (delete existing node group first if needed)"

ec2-config-set-as-spot:
	@echo "Setting EC2 capacity type to SPOT..."
	@sed -i.bak 's/^node_capacity_type = "ON_DEMAND"/node_capacity_type = "SPOT"/' $(TFVARS_FILE)
	@rm -f $(TFVARS_FILE).bak
	@echo "✅ EC2 capacity type set to SPOT"
	@echo "   Run 'make tf-apply' to apply changes (delete existing node group first if needed)"

ec2-config-status:
	@echo "=== EC2 Node Configuration ==="
	@grep -E "^node_capacity_type" $(TFVARS_FILE) || echo "node_capacity_type not set (default: ON_DEMAND)"
	@echo ""
	@echo "Options:"
	@echo "  ON_DEMAND - Standard EC2 instances (stable, uses On-Demand quota)"
	@echo "  SPOT      - Spot instances (cheaper, uses Spot quota, can be interrupted)"

# AWS Region Configuration
# These commands switch deployment between us-east-1 and us-east-2
# IMPORTANT: Changing regions requires destroying existing infrastructure first
ENV_FILE := .env
BACKEND_HCL := infra/terraform/envs/demo/backend.hcl
TF_DIR := infra/terraform/envs/demo

region-status:
	@echo "=== AWS Region Configuration ==="
	@echo ""
	@echo "Current settings:"
	@echo -n "  .env:            "; grep -E "^DEPLOY_AWS_REGION=" $(ENV_FILE) | cut -d= -f2 || echo "(not set)"
	@echo -n "  terraform.tfvars: "; grep -E "^aws_region" $(TFVARS_FILE) | sed 's/.*= *"//' | sed 's/"//' || echo "(not set)"
	@echo -n "  backend.hcl:      "; grep -E "^region" $(BACKEND_HCL) | sed 's/.*= *"//' | sed 's/"//' || echo "(not set)"
	@echo ""
	@echo "Available regions:"
	@echo "  us-east-1 - N. Virginia"
	@echo "  us-east-2 - Ohio"

region-set-us-east-1:
	@echo "⚠️  IMPORTANT: Changing regions requires these steps:"
	@echo ""
	@echo "1. First, DESTROY existing infrastructure in the current region:"
	@echo "   make tf-destroy"
	@echo ""
	@echo "2. Then run this command again to update config files"
	@echo ""
	@echo "3. Deploy to the new region:"
	@echo "   make tf-apply"
	@echo ""
	@read -p "Have you destroyed existing infrastructure? (y/N) " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "Updating region to us-east-1..."; \
		sed -i.bak 's/^DEPLOY_AWS_REGION=.*/DEPLOY_AWS_REGION=us-east-1/' $(ENV_FILE); \
		sed -i.bak 's/^aws_region.*/aws_region  = "us-east-1"/' $(TFVARS_FILE); \
		rm -f $(ENV_FILE).bak $(TFVARS_FILE).bak; \
		echo "✅ Region set to us-east-1 (N. Virginia)"; \
		echo ""; \
		echo "Next step: make tf-apply"; \
	else \
		echo "❌ Aborted. Run 'make tf-destroy' first, then try again."; \
	fi

region-set-us-east-2:
	@echo "⚠️  IMPORTANT: Changing regions requires these steps:"
	@echo ""
	@echo "1. First, DESTROY existing infrastructure in the current region:"
	@echo "   make tf-destroy"
	@echo ""
	@echo "2. Then run this command again to update config files"
	@echo ""
	@echo "3. Deploy to the new region:"
	@echo "   make tf-apply"
	@echo ""
	@read -p "Have you destroyed existing infrastructure? (y/N) " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "Updating region to us-east-2..."; \
		sed -i.bak 's/^DEPLOY_AWS_REGION=.*/DEPLOY_AWS_REGION=us-east-2/' $(ENV_FILE); \
		sed -i.bak 's/^aws_region.*/aws_region  = "us-east-2"/' $(TFVARS_FILE); \
		rm -f $(ENV_FILE).bak $(TFVARS_FILE).bak; \
		echo "✅ Region set to us-east-2 (Ohio)"; \
		echo ""; \
		echo "Next step: make tf-apply"; \
	else \
		echo "❌ Aborted. Run 'make tf-destroy' first, then try again."; \
	fi
