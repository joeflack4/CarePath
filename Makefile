.PHONY: help install-db-api install-chat run-db-api run-chat load-synthetic generate-synthetic download-llm-model \
install-chat-llm test-triage docker-build-db-api docker-build-chat docker-push-db-api docker-push-chat ecr-login \
aws-login tf-login tf-init tf-plan tf-apply tf-destroy tf-destroy-nuclear shutdown-nodes shutdown-all shutdown-all-nuclear spinup-all deploy-db-api deploy-chat deploy-all mongo-local-start-macos \
mongo-local-install-macos k8s-config k8s-status k8s-get-urls k8s-logs k8s-logs-chat k8s-logs-db \
k8s-logs-chat-errors k8s-logs-db-errors k8s-logs-all-errors k8s-pods-list k8s-scale-up k8s-scale-down \
k8s-rollback-db-api k8s-rollback-chat k8s-rollback-all k8s-restart-db-api k8s-restart-chat k8s-history \
ec2-config-set-as-nodes ec2-config-set-as-spot ec2-config-status region-set-us-east-1 region-set-us-east-2 \
region-status docker-push-all test-triage-cloud test-triage-local \
frontend-install frontend-build frontend-deploy frontend-dev frontend-dev-local frontend-dev-cloud frontend-invalidate-cache \
install-load-tests load-test-db-api load-test-chat load-test-db-api-10rps load-test-db-api-100rps load-test-db-api-1000rps \
load-test-chat-10rps load-test-chat-100rps load-test-chat-1000rps load-test-web-db-api load-test-web-chat load-test-results

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
	@echo "  make tf-destroy-nuclear  - Destroy resources AND delete state file (cannot undo!)"
	@echo ""
	@echo "Shutdown / Cost Savings:"
	@echo "  make shutdown-nodes         - Scale EKS nodes to 0 (partial savings, keeps infra)"
	@echo "  make shutdown-all           - Destroy all infrastructure (keeps state, can spinup)"
	@echo "  make shutdown-all-nuclear   - Destroy everything including state (cannot spinup!)"
	@echo "  make spinup-all             - Rebuild infrastructure from scratch"
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
	@echo "  make k8s-logs-chat       - Stream chat-api logs"
	@echo "  make k8s-logs-db         - Stream db-api logs"
	@echo "  make k8s-logs-all-errors - Show errors from all services"
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
	@echo ""
	@echo "Frontend:"
	@echo "  make frontend-install        - Install frontend dependencies"
	@echo "  make frontend-dev-local      - Run frontend dev server (local APIs)"
	@echo "  make frontend-dev-cloud      - Run frontend dev server (cloud APIs)"
	@echo "  make frontend-build          - Build frontend for production"
	@echo "  make frontend-deploy         - Deploy frontend to S3/CloudFront"
	@echo "  make frontend-invalidate-cache - Invalidate CloudFront cache"
	@echo ""
	@echo "Load Testing:"
	@echo "  make install-load-tests      - Install Locust load testing dependencies"
	@echo "  make load-test-db-api        - Run DB API load test (default settings)"
	@echo "  make load-test-chat          - Run Chat API load test (default settings)"
	@echo "  make load-test-db-api-10rps  - DB API load test at 10 RPS"
	@echo "  make load-test-db-api-100rps - DB API load test at 100 RPS"
	@echo "  make load-test-db-api-1000rps - DB API load test at 1000 RPS"
	@echo "  make load-test-chat-10rps    - Chat API load test at 10 RPS"
	@echo "  make load-test-chat-100rps   - Chat API load test at 100 RPS"
	@echo "  make load-test-chat-1000rps  - Chat API load test at 1000 RPS"
	@echo "  make load-test-web-db-api    - Start Locust web UI for DB API"
	@echo "  make load-test-web-chat      - Start Locust web UI for Chat API"
	@echo "  make load-test-results       - Display results from last load test"

ifneq (,$(wildcard .env))
include .env
export  # export included vars to child processes
endif

# Include load testing targets
include Makefile.load_tests

# Demo API URLs (update after deployment with `make k8s-get-urls`)
# https://tinyurl.com/flack-bwell-demo-api
DEMO_CHAT_SERVICE_URL=http://ae650096299bf4232b4e4b1df1ac3901-1174130703.us-east-2.elb.amazonaws.com
DEMO_DB_API_URL=http://a61c57f3d91604c4188d136aa564bb0a-1897210492.us-east-2.elb.amazonaws.com

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
	@echo "This may take a while (~8GB download)..."
	MODEL_CACHE_DIR=./models python -m service_chat.utils.download_model
	@echo ""
	@echo "To use this model locally, set in .env:"
	@echo "  MODEL_CACHE_DIR=./models"
	@echo "  LLM_MODE=Qwen3-4B-Thinking-2507"

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
	@export TF_VAR_hf_api_token="$$(grep '^HF_API_TOKEN=' .env 2>/dev/null | cut -d= -f2 || echo 'dummy')" && \
	cd infra/terraform/envs/demo && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform destroy

tf-destroy-nuclear:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "☢️  NUCLEAR DESTROY: Destroying infrastructure AND state"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "⚠️  DANGER: This will delete the Terraform state file"
	@echo "⚠️  You will NOT be able to manage these resources with Terraform again"
	@echo ""
	@read -p "Type 'nuclear' to confirm: " confirm; \
	if [ "$$confirm" != "nuclear" ]; then \
		echo "Aborted."; \
		exit 1; \
	fi
	@echo ""
	@echo "Step 1/2: Destroying Terraform resources..."
	@export TF_VAR_hf_api_token="$$(grep '^HF_API_TOKEN=' .env 2>/dev/null | cut -d= -f2 || echo 'dummy')" && \
	cd infra/terraform/envs/demo && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform destroy -auto-approve
	@echo ""
	@echo "Step 2/2: Deleting Terraform state file..."
	@aws s3 rm s3://genonaut-terraform-state/carepath/demo/terraform.tfstate --profile $(DEPLOY_AWS_PROFILE) --region us-east-1 2>/dev/null || echo "  (state file already deleted or doesn't exist)"
	@echo ""
	@echo "☢️  NUCLEAR DESTROY COMPLETE - State file deleted"

# Shutdown / Cost Savings Commands
shutdown-nodes: k8s-config
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "⚠️  PARTIAL SHUTDOWN: Scaling EKS node group to 0"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "This will:"
	@echo "  ✓ Stop all EC2 instances (saves EC2 costs)"
	@echo "  ✓ Stop all running pods"
	@echo "  ✗ Keep EKS control plane (still incurs costs)"
	@echo "  ✗ Keep NAT Gateway (still incurs costs)"
	@echo "  ✗ Keep Load Balancers (still incurs costs)"
	@echo ""
	@echo "To spin back up: Run 'kubectl scale' manually or redeploy"
	@echo "To save MORE: Use 'make shutdown-all' instead"
	@echo ""
	@read -p "Continue? [y/N] " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo "Aborted."; \
		exit 1; \
	fi
	@echo ""
	@echo "Scaling node group to 0..."
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
		aws eks update-nodegroup-config \
		--cluster-name carepath-demo-cluster \
		--nodegroup-name carepath-demo-cluster-node-group \
		--scaling-config minSize=0,maxSize=0,desiredSize=0
	@echo ""
	@echo "✅ Node group scaled to 0"
	@echo "💰 EC2 costs stopped, but EKS/NAT/LB costs remain"

shutdown-all:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "🛑  FULL SHUTDOWN: Destroying ALL infrastructure"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "This will DESTROY:"
	@echo "  • EKS cluster and all pods"
	@echo "  • EC2 instances (node group)"
	@echo "  • NAT Gateway and Elastic IPs"
	@echo "  • Load Balancers"
	@echo "  • VPC, subnets, route tables"
	@echo "  • Security groups"
	@echo "  • S3 frontend bucket (will be emptied first)"
	@echo "  • ECR Docker images (will be deleted)"
	@echo ""
	@echo "This will KEEP:"
	@echo "  ✓ CloudFront distribution"
	@echo "  ✓ Terraform state (S3 backend)"
	@echo ""
	@echo "To spin back up: Run 'make spinup-all' (~10-15 min)"
	@echo ""
	@echo "⚠️  WARNING: This cannot be easily undone!"
	@echo ""
	@read -p "Type 'destroy' to confirm: " confirm; \
	if [ "$$confirm" != "destroy" ]; then \
		echo "Aborted."; \
		exit 1; \
	fi
	@echo ""
	@echo "Step 1/3: Emptying S3 frontend bucket..."
	@aws s3 rm s3://carepath-demo-frontend --recursive --profile $(DEPLOY_AWS_PROFILE) --region $(DEPLOY_AWS_REGION) 2>/dev/null || echo "  (bucket already empty or doesn't exist)"
	@echo ""
	@echo "Step 2/3: Applying force_delete to ECR repositories..."
	@export TF_VAR_hf_api_token="$$(grep '^HF_API_TOKEN=' .env 2>/dev/null | cut -d= -f2 || echo 'dummy')" && \
	cd infra/terraform/envs/demo && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform apply -target=module.ecr.aws_ecr_repository.chat_api -target=module.ecr.aws_ecr_repository.db_api -auto-approve
	@echo ""
	@echo "Step 3/3: Running terraform destroy..."
	@export TF_VAR_hf_api_token="$$(grep '^HF_API_TOKEN=' .env 2>/dev/null | cut -d= -f2 || echo 'dummy')" && \
	cd infra/terraform/envs/demo && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform destroy -auto-approve
	@echo ""
	@echo "✅ All infrastructure destroyed"
	@echo "💰 Costs reduced to minimal S3 storage fees"

shutdown-all-nuclear:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "☢️  NUCLEAR SHUTDOWN: Destroying EVERYTHING including state"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "This will DESTROY:"
	@echo "  • EKS cluster and all pods"
	@echo "  • EC2 instances (node group)"
	@echo "  • NAT Gateway and Elastic IPs"
	@echo "  • Load Balancers"
	@echo "  • VPC, subnets, route tables"
	@echo "  • Security groups"
	@echo "  • S3 frontend bucket"
	@echo "  • ECR Docker images"
	@echo "  • Terraform state file (cannot spin back up easily!)"
	@echo ""
	@echo "This will KEEP:"
	@echo "  ✓ CloudFront distribution"
	@echo "  ✓ Shared Genonaut S3 state bucket (only CarePath state file deleted)"
	@echo ""
	@echo "⚠️  DANGER: Without state, you CANNOT use 'make spinup-all'"
	@echo "⚠️  You would need to re-run 'terraform import' for all resources"
	@echo "⚠️  Or start completely fresh with new infrastructure"
	@echo ""
	@read -p "Type 'nuclear' to confirm PERMANENT deletion: " confirm; \
	if [ "$$confirm" != "nuclear" ]; then \
		echo "Aborted."; \
		exit 1; \
	fi
	@echo ""
	@echo "Step 1/4: Emptying S3 frontend bucket..."
	@aws s3 rm s3://carepath-demo-frontend --recursive --profile $(DEPLOY_AWS_PROFILE) --region $(DEPLOY_AWS_REGION) 2>/dev/null || echo "  (bucket already empty or doesn't exist)"
	@echo ""
	@echo "Step 2/4: Applying force_delete to ECR repositories..."
	@export TF_VAR_hf_api_token="$$(grep '^HF_API_TOKEN=' .env 2>/dev/null | cut -d= -f2 || echo 'dummy')" && \
	cd infra/terraform/envs/demo && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform apply -target=module.ecr.aws_ecr_repository.chat_api -target=module.ecr.aws_ecr_repository.db_api -auto-approve
	@echo ""
	@echo "Step 3/4: Running terraform destroy..."
	@export TF_VAR_hf_api_token="$$(grep '^HF_API_TOKEN=' .env 2>/dev/null | cut -d= -f2 || echo 'dummy')" && \
	cd infra/terraform/envs/demo && \
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) AWS_REGION=$(DEPLOY_AWS_REGION) \
	terraform destroy -auto-approve
	@echo ""
	@echo "Step 4/4: Deleting Terraform state file from S3..."
	@aws s3 rm s3://genonaut-terraform-state/carepath/demo/terraform.tfstate --profile $(DEPLOY_AWS_PROFILE) --region us-east-1 2>/dev/null || echo "  (state file already deleted or doesn't exist)"
	@echo ""
	@echo "☢️  NUCLEAR SHUTDOWN COMPLETE"
	@echo "💰 Costs reduced to near-zero (only CloudFront if still active)"
	@echo ""
	@echo "⚠️  State destroyed - cannot easily spin back up"

spinup-all:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "🚀  SPIN UP: Rebuilding infrastructure"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "This will create:"
	@echo "  • EKS cluster (~10 min)"
	@echo "  • EC2 instances (node group)"
	@echo "  • NAT Gateway and networking"
	@echo "  • Load Balancers"
	@echo "  • Deploy db-api and chat-api pods"
	@echo ""
	@echo "Estimated time: 10-15 minutes"
	@echo ""
	@read -p "Continue? [y/N] " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo "Aborted."; \
		exit 1; \
	fi
	@echo ""
	@echo "Step 1/3: Terraform apply..."
	@$(MAKE) tf-apply
	@echo ""
	@echo "Step 2/3: Configure kubectl..."
	@$(MAKE) k8s-config
	@echo ""
	@echo "Step 3/3: Checking deployment status..."
	@$(MAKE) k8s-status
	@echo ""
	@echo "✅ Infrastructure rebuilt successfully"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Check service URLs: make k8s-get-urls"
	@echo "  2. View logs: make k8s-logs-chat"
	@echo "  3. Test endpoints: make test-triage-cloud"

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
	@echo ""
	@echo "Updating frontend with new API URLs..."
	@$(MAKE) frontend-deploy
	@echo "✅ Frontend updated with latest API endpoints"

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
	@DB_TYPE=$$(kubectl get svc db-api-service -n $(K8S_NAMESPACE) -o jsonpath='{.spec.type}' 2>/dev/null); \
	if [ "$$DB_TYPE" = "LoadBalancer" ]; then \
		echo "DB API (External LoadBalancer):"; \
		kubectl get svc db-api-service -n $(K8S_NAMESPACE) -o jsonpath='  URL: http://{.status.loadBalancer.ingress[0].hostname}{"\n"}' 2>/dev/null || echo "  (LoadBalancer provisioning...)"; \
	else \
		echo "DB API (Internal ClusterIP - not externally accessible):"; \
		kubectl get svc db-api-service -n $(K8S_NAMESPACE) -o jsonpath='  Internal: {.spec.clusterIP}:{.spec.ports[0].port}{"\n"}' 2>/dev/null || echo "  (not available)"; \
	fi

k8s-pods-list:
	kubectl get pods -n $(K8S_NAMESPACE) -o wide

k8s-logs:
	@if [ -z "$(s)" ]; then \
		echo "Usage: make k8s-logs s=SERVICE"; \
		echo "  SERVICE: db-api or chat-api"; \
		exit 1; \
	fi
	kubectl logs -l app=$(s) -n $(K8S_NAMESPACE) --tail=100 -f

# Convenience log shortcuts
k8s-logs-chat:
	@echo "=== Chat API Logs (last 100 lines, streaming) ==="
	kubectl logs -l app=chat-api -n $(K8S_NAMESPACE) --tail=100 -f

k8s-logs-db:
	@echo "=== DB API Logs (last 100 lines, streaming) ==="
	kubectl logs -l app=db-api -n $(K8S_NAMESPACE) --tail=100 -f

k8s-logs-chat-errors:
	@echo "=== Chat API Errors (last 200 lines) ==="
	kubectl logs -l app=chat-api -n $(K8S_NAMESPACE) --tail=200 | grep -iE "(error|exception|traceback|500|failed)" || echo "No errors found"

k8s-logs-db-errors:
	@echo "=== DB API Errors (last 200 lines) ==="
	kubectl logs -l app=db-api -n $(K8S_NAMESPACE) --tail=200 | grep -iE "(error|exception|traceback|500|failed)" || echo "No errors found"

k8s-logs-all-errors:
	@echo "=== All Service Errors ==="
	@echo ""
	@echo "--- Chat API ---"
	@kubectl logs -l app=chat-api -n $(K8S_NAMESPACE) --tail=200 2>/dev/null | grep -iE "(error|exception|traceback|500|failed)" || echo "No errors found"
	@echo ""
	@echo "--- DB API ---"
	@kubectl logs -l app=db-api -n $(K8S_NAMESPACE) --tail=200 2>/dev/null | grep -iE "(error|exception|traceback|500|failed)" || echo "No errors found"

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

# Frontend targets
FRONTEND_DIR := frontend_chat
FRONTEND_S3_BUCKET := $(shell cd infra/terraform/envs/demo && AWS_PROFILE=$(DEPLOY_AWS_PROFILE) terraform output -raw frontend_bucket_name 2>/dev/null || echo "")
FRONTEND_CF_DIST_ID := $(shell cd infra/terraform/envs/demo && AWS_PROFILE=$(DEPLOY_AWS_PROFILE) terraform output -raw frontend_cloudfront_distribution_id 2>/dev/null || echo "")

frontend-install:
	@echo "Installing frontend dependencies..."
	cd $(FRONTEND_DIR) && npm install
	@echo "✅ Frontend dependencies installed"

frontend-dev-local:
	@echo "Starting frontend dev server with LOCAL APIs..."
	@echo "Make sure db-api (port 8001) and chat-api (port 8002) are running locally"
	cd $(FRONTEND_DIR) && VITE_DB_API_URL=http://localhost:8001 VITE_CHAT_API_URL=http://localhost:8002 npm run dev

frontend-dev-cloud:
	@echo "Starting frontend dev server with CLOUD APIs..."
	cd $(FRONTEND_DIR) && VITE_DB_API_URL=$(DEMO_DB_API_URL) VITE_CHAT_API_URL=$(DEMO_CHAT_SERVICE_URL) npm run dev

# Alias for backward compatibility
frontend-dev: frontend-dev-cloud

frontend-live:
	open http://carepath-demo-frontend.s3-website.us-east-2.amazonaws.com/

frontend-build:
	@echo "Building frontend for production..."
	@echo "Fetching API URLs from Terraform outputs..."
	@DB_API_LB=$$(cd infra/terraform/envs/demo && AWS_PROFILE=$(DEPLOY_AWS_PROFILE) terraform output -raw db_api_load_balancer_hostname 2>/dev/null); \
	CHAT_API_LB=$$(cd infra/terraform/envs/demo && AWS_PROFILE=$(DEPLOY_AWS_PROFILE) terraform output -raw chat_api_load_balancer_hostname 2>/dev/null); \
	if [ -n "$$DB_API_LB" ] && [ -n "$$CHAT_API_LB" ]; then \
		echo "Using API URLs from Terraform:"; \
		echo "  DB API: http://$$DB_API_LB"; \
		echo "  Chat API: http://$$CHAT_API_LB"; \
		VITE_DB_API_URL="http://$$DB_API_LB" VITE_CHAT_API_URL="http://$$CHAT_API_LB" cd $(FRONTEND_DIR) && npm run build; \
	else \
		echo "⚠️  Warning: Could not fetch Terraform outputs, using .env file values"; \
		cd $(FRONTEND_DIR) && npm run build; \
	fi
	@echo "✅ Frontend built to $(FRONTEND_DIR)/dist/"

frontend-deploy: frontend-build
	@echo "Deploying frontend to S3..."
	@if [ -z "$(FRONTEND_S3_BUCKET)" ]; then \
		echo "Error: S3 bucket not found. Run 'make tf-apply' first to create frontend infrastructure."; \
		exit 1; \
	fi
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) aws s3 sync $(FRONTEND_DIR)/dist/ s3://$(FRONTEND_S3_BUCKET)/ --delete
	@echo "✅ Frontend deployed to s3://$(FRONTEND_S3_BUCKET)/"
	@echo ""
	@echo "Invalidating CloudFront cache..."
	@if [ -n "$(FRONTEND_CF_DIST_ID)" ]; then \
		AWS_PROFILE=$(DEPLOY_AWS_PROFILE) aws cloudfront create-invalidation --distribution-id $(FRONTEND_CF_DIST_ID) --paths "/*" > /dev/null; \
		echo "✅ CloudFront cache invalidated"; \
	else \
		echo "⚠️  CloudFront distribution ID not found, skipping cache invalidation"; \
	fi
	@echo ""
	@echo "Frontend URL:"
	@cd infra/terraform/envs/demo && AWS_PROFILE=$(DEPLOY_AWS_PROFILE) terraform output frontend_url

frontend-invalidate-cache:
	@echo "Invalidating CloudFront cache..."
	@if [ -z "$(FRONTEND_CF_DIST_ID)" ]; then \
		echo "Error: CloudFront distribution ID not found. Run 'make tf-apply' first."; \
		exit 1; \
	fi
	AWS_PROFILE=$(DEPLOY_AWS_PROFILE) aws cloudfront create-invalidation --distribution-id $(FRONTEND_CF_DIST_ID) --paths "/*"
	@echo "✅ CloudFront cache invalidation requested"
