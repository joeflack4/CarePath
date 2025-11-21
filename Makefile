.PHONY: help install-db-api install-chat run-db-api run-chat load-synthetic generate-synthetic download-llm-model \
install-chat-llm test-triage docker-build-db-api docker-build-chat docker-push-db-api docker-push-chat ecr-login \
aws-login tf-login tf-init tf-plan tf-apply tf-destroy deploy-db-api deploy-chat deploy-all mongo-local-start-macos \
mongo-local-install-macos

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

ifneq (,$(wildcard .env))
include .env
export  # export included vars to child processes
endif

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

test-triage:
	@echo "Testing /triage endpoint..."
	@curl -s -X POST http://localhost:8002/triage \
		-H "Content-Type: application/json" \
		-d '{"patient_mrn": "P000123", "query": "$(if $(m),$(m),What are my current medications?)"}' | python -m json.tool
	@echo ""
	@echo "✅ Test complete"

mongo-local-install-macos:
	brew tap mongodb/brew
	brew install mongodb-community@7.0

mongo-local-start-macos:
	brew services start mongodb-community@7.0

# Docker / Build targets
# Get ECR URLs from Terraform outputs
ECR_DB_API_URL := $(shell cd infra/terraform/envs/demo && terraform output -raw db_api_repo_url 2>/dev/null || echo "")
ECR_CHAT_API_URL := $(shell cd infra/terraform/envs/demo && terraform output -raw chat_api_repo_url 2>/dev/null || echo "")
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
AWS_REGION := $(shell echo $(DEPLOY_AWS_REGION))

docker-build-db-api:
	@echo "Building Docker image for db-api..."
	docker build -t carepath-db-api:latest -f service_db_api/Dockerfile service_db_api/

docker-build-chat:
	@echo "Building Docker image for chat-api..."
	docker build -t carepath-chat-api:latest -f service_chat/Dockerfile service_chat/

ecr-login:
	@echo "Logging into ECR..."
	aws ecr get-login-password --region $(AWS_REGION) | \
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
	cd infra/terraform/envs/demo && terraform init -backend-config=backend.hcl

tf-plan:
	@echo "Planning Terraform changes..."
	cd infra/terraform/envs/demo && terraform plan

tf-apply:
	@echo "Applying Terraform changes..."
	cd infra/terraform/envs/demo && terraform apply

tf-destroy:
	@echo "Destroying Terraform resources..."
	cd infra/terraform/envs/demo && terraform destroy

# Deployment targets
deploy-db-api: docker-build-db-api docker-push-db-api
	@echo "Deploying db-api..."
	@echo "Updating Terraform with new image..."
	cd infra/terraform/envs/demo && terraform apply -target=module.app.kubernetes_deployment.db_api -auto-approve
	@echo "✅ db-api deployed successfully"

deploy-chat: docker-build-chat docker-push-chat
	@echo "Deploying chat-api..."
	@echo "Updating Terraform with new image..."
	cd infra/terraform/envs/demo && terraform apply -target=module.app.kubernetes_deployment.chat_api -auto-approve
	@echo "✅ chat-api deployed successfully"

deploy-all: docker-build-db-api docker-build-chat docker-push-db-api docker-push-chat
	@echo "Deploying all services..."
	@echo "Running full Terraform apply..."
	cd infra/terraform/envs/demo && terraform apply
	@echo "✅ All services deployed successfully"
