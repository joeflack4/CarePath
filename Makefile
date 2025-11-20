.PHONY: help install-db-api install-chat run-db-api run-chat load-synthetic generate-synthetic

# Default target
help:
	@echo "CarePath AI - Available Make Targets"
	@echo ""
	@echo "Development:"
	@echo "  make install-db-api      - Install dependencies for service_db_api"
	@echo "  make install-chat        - Install dependencies for service_chat"
	@echo "  make run-db-api          - Run db API locally with uvicorn"
	@echo "  make run-chat            - Run chat API locally with uvicorn"
	@echo "  make generate-synthetic  - Generate synthetic data files"
	@echo "  make load-synthetic      - Load synthetic data into MongoDB"
	@echo ""
	@echo "Docker / Build:"
	@echo "  make docker-build-db-api - Build Docker image for db-api"
	@echo "  make docker-build-chat   - Build Docker image for chat-api"
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

# Development targets
install-db-api:
	@echo "Installing dependencies for service_db_api..."
	pip install fastapi uvicorn motor pymongo pydantic-settings

install-chat:
	@echo "Installing dependencies for service_chat..."
	pip install fastapi uvicorn httpx pydantic-settings

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

# Docker / Build targets (to be implemented)
docker-build-db-api:
	@echo "Docker build for db-api not yet implemented"

docker-build-chat:
	@echo "Docker build for chat not yet implemented"

docker-push-db-api:
	@echo "Docker push for db-api not yet implemented"

docker-push-chat:
	@echo "Docker push for chat not yet implemented"

# Infrastructure targets (to be implemented)
tf-init:
	@echo "Terraform init not yet implemented"

tf-plan:
	@echo "Terraform plan not yet implemented"

tf-apply:
	@echo "Terraform apply not yet implemented"

tf-destroy:
	@echo "Terraform destroy not yet implemented"

# Deployment targets (to be implemented)
deploy-db-api:
	@echo "Deploy db-api not yet implemented"

deploy-chat:
	@echo "Deploy chat not yet implemented"

deploy-all:
	@echo "Deploy all not yet implemented"
