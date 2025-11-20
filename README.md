# CarePath AI

An AI assistant backend that helps patients understand their health history and upcoming care.

## Overview

CarePath AI is a multi-service healthcare demo built with Python and FastAPI, demonstrating:
- **MongoDB-backed API** for healthcare data (patients, encounters, claims, documents)
- **AI chat service** with RAG (Retrieval Augmented Generation) capabilities
- **Mock LLM** for MVP (with scaffolding for real models like Qwen3-4B)
- **Vector database integration** scaffold (Pinecone, not wired in MVP)
- **Simple distributed tracing** with trace IDs
- **PHI scrubbing** placeholder for HIPAA compliance

## Architecture

```
┌─────────────────┐         HTTP          ┌──────────────────┐
│  service_chat   │ ──────────────────▶   │ service_db_api   │
│  (AI Assistant) │                        │  (MongoDB API)   │
│  Port: 8002     │                        │  Port: 8001      │
└─────────────────┘                        └──────────────────┘
        │                                           │
        │ LLM (Mock)                               │
        │ Vector DB (Mock)                         │
        │                                          │
        ▼                                          ▼
   (Future: Qwen3)                           MongoDB Atlas
   (Future: Pinecone)
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

### service_db_api (Port 8001)

- `GET /health` - Health check
- `GET /health/db` - Database connectivity check
- `GET /patients` - List patients (paginated)
- `GET /patients/{mrn}` - Get patient by MRN
- `GET /patients/{mrn}/summary` - Get comprehensive patient summary
- `GET /encounters` - List encounters
- `GET /claims` - List claims
- `GET /documents` - List documents
- `GET /chat-logs` - List chat logs

### service_chat (Port 8002)

- `GET /health` - Health check
- `POST /triage` - AI-powered patient assistance

## Development Status

**Completed (Phases 1-3):**
- ✅ Repository structure and environment setup
- ✅ MongoDB API with all core endpoints
- ✅ Synthetic data generation and loading
- ✅ AI chat service with mock LLM
- ✅ RAG scaffolding (using patient summary)
- ✅ Distributed tracing with trace IDs
- ✅ PHI scrubbing placeholder
- ✅ Makefile automation

**TODO (Phases 4-6):**
- ⏳ Docker images for both services
- ⏳ Terraform infrastructure (EKS, ECR, MongoDB Atlas)
- ⏳ HPA (Horizontal Pod Autoscaler) configuration
- ⏳ Real LLM integration (Qwen3-4B-Thinking-2507)
- ⏳ Pinecone vector database integration
- ⏳ Async document ingestion pipeline
- ⏳ Enhanced tracing (OpenTelemetry)

See `notes/mvp-ig/` for detailed implementation guides.

## Makefile Commands

```bash
# Development
make install-db-api      # Install DB API dependencies
make install-chat        # Install Chat API dependencies
make run-db-api          # Run DB API locally
make run-chat            # Run Chat API locally
make generate-synthetic  # Generate synthetic data
make load-synthetic      # Load data into MongoDB

# Docker (to be implemented)
make docker-build-db-api
make docker-build-chat
make docker-push-db-api
make docker-push-chat

# Infrastructure (to be implemented)
make tf-init
make tf-plan
make tf-apply
make tf-destroy

# Deployment (to be implemented)
make deploy-db-api
make deploy-chat
make deploy-all
```

## Tech Stack

- **Backend:** Python 3.11+, FastAPI, Uvicorn
- **Database:** MongoDB (Motor async driver)
- **HTTP Client:** httpx
- **Configuration:** pydantic-settings
- **LLM (Future):** Qwen3-4B-Thinking-2507
- **Vector DB (Future):** Pinecone
- **Infrastructure (Future):** AWS EKS, Terraform, Docker

## Contributing

This is a demo project for showcasing microservices architecture with AI/ML integration in healthcare.

## License

[To be determined]
