# CarePath AI

An AI assistant backend that helps patients understand their health history and upcoming care.

## Overview

CarePath AI is a multi-service healthcare demo built with Python and FastAPI, demonstrating:
- **MongoDB-backed API** for healthcare data (patients, encounters, claims, documents)
- **AI chat service** with RAG (Retrieval Augmented Generation) capabilities
- **LLM Integration** with Qwen3-4B-Thinking-2507 model (CPU-based inference)
- **Mock LLM mode** for testing and development
- **Vector database integration** scaffold (Pinecone, not wired in MVP)
- **Simple distributed tracing** with trace IDs
- **PHI scrubbing** placeholder for HIPAA compliance

## Architecture

```
┌─────────────────┐         HTTP           ┌──────────────────┐
│  service_chat   │ ──────────────────▶    │ service_db_api   │
│  (AI Assistant) │                        │  (MongoDB API)   │
│  Port: 8002     │                        │  Port: 8001      │
└─────────────────┘                        └──────────────────┘
        │                                           │
        │                                           │
        │                                           │
        │                                           │
        ▼                                           ▼
   ( LLM )                                    MongoDB Atlas
   ( Pinecone )
```

## Quick Start

### Prerequisites
- Python 3.11+
- MongoDB (local or Atlas)
- Virtual environment activated: `source env/python_venv/bin/activate`

### Installation

```bash
# Install dependencies for both services
make install-db-api
make install-chat

# Generate and load synthetic data
make generate-synthetic
make load-synthetic
```

### Running Services

```bash
# Terminal 1: Start MongoDB API
make run-db-api

# Terminal 2: Start Chat API
make run-chat
```

### Testing

```bash
# Test DB API health
curl http://localhost:8001/health

# Test patient summary endpoint
curl http://localhost:8001/patients/P000123/summary

# Test Chat API triage endpoint
curl -X POST http://localhost:8002/triage \
  -H "Content-Type: application/json" \
  -d '{
    "patient_mrn": "P000123",
    "query": "Why did my doctor change my diabetes medication?"
  }'
```

## Project Structure

```
CarePath/
├── service_db_api/          # MongoDB-backed data API
│   ├── main.py
│   ├── config.py
│   ├── db/
│   │   └── mongo.py
│   ├── models/              # Pydantic models
│   └── routers/             # FastAPI routers
├── service_chat/            # AI chat service
│   ├── main.py
│   ├── config.py
│   ├── tracing.py           # Simple tracing
│   ├── scrub_phi.py         # PHI scrubbing placeholder
│   ├── routers/
│   │   ├── health.py
│   │   └── triage.py
│   └── services/
│       ├── db_client.py     # HTTP client to service_db_api
│       ├── llm_client.py    # LLM interface (mock + future real)
│       ├── rag_service.py   # RAG orchestration
│       └── pinecone_client.py  # Vector DB scaffold
├── scripts/
│   ├── generate_synthetic_data.py
│   └── load_synthetic_data.py
├── data/
│   └── synthetic/           # Generated JSONL files
└── notes/mvp-ig/            # Implementation guides
```

## Environment Configuration

Copy `.env.example` to `.env` and configure:

```bash
# service_db_api
MONGODB_URI=mongodb://localhost:27017
MONGODB_DB_NAME=carepath
API_PORT_DB_API=8001

# service_chat
CHAT_API_PORT=8002
DB_API_BASE_URL=http://localhost:8001
LLM_MODE=mock
VECTOR_MODE=mock
```

## API Documentation

Full API documentation with request/response examples:

- **[Database API (service_db_api)](docs/api-db.md)** - Port 8001
  - Health checks, patients, encounters, claims, documents, chat logs
  - Patient summary endpoint for RAG context

- **[Chat API (service_chat)](docs/api-chat.md)** - Port 8002
  - Health check and `/triage` endpoint
  - Includes curl examples and expected responses
  - `make test-triage` for quick testing

See `notes/mvp-ig/` for detailed implementation guides.

## Documentation

- **[Model Management](docs/models.md)** - How to download, deploy, and manage LLM models
- **[Infrastructure Guide](infra/terraform/README.md)** - Terraform setup and deployment instructions
- **[Deployment Options](docs/rollout-options.md)** - Different strategies for deploying services
- **[AI Service Upgrade](notes/issues/6-very-high/ai-service-upgrade.md)** - Step-by-step guide for deploying Qwen LLM

## Makefile Command summary

```bash
# Development
make install-db-api      # Install DB API dependencies
make install-chat        # Install Chat API dependencies
make install-chat-llm    # Install LLM dependencies (torch, transformers)
make run-db-api          # Run DB API locally
make run-chat            # Run Chat API locally
make generate-synthetic  # Generate synthetic data
make load-synthetic      # Load data into MongoDB
make download-llm-model  # Download Qwen3-4B-Thinking-2507 model
make test-triage         # Test the /triage endpoint

# Docker
make docker-build-db-api
make docker-build-chat
make docker-push-db-api
make docker-push-chat

# Infrastructure
make tf-init
make tf-plan
make tf-apply
make tf-destroy

# Deployment
make deploy-db-api
make deploy-chat
make deploy-all
```

## Tech Stack

- **Backend:** Python 3.11+, FastAPI, Uvicorn
- **Database:** MongoDB (Motor async driver)
- **HTTP Client:** httpx
- **Configuration:** pydantic-settings
- **LLM:** Qwen3-4B-Thinking-2507 (via Hugging Face Transformers)
- **Vector DB (Future):** Pinecone
- **Infrastructure:** AWS EKS, Terraform, Docker, ECR
