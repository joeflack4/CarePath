# CarePath AI – Multi-Service Demo (Main Orchestration Spec)

This document is the high-level “outer loop” for the project. It explains **what to build first**, how the pieces fit, and where to find detailed specs.

---

## 1. Goals

- [x] Demonstrate backend microservices (Python + FastAPI)
- [x] Demonstrate MongoDB modeling and APIs for healthcare-like data
- [x] Demonstrate AI chat service using RAG over the Mongo API
- [x] Demonstrate vector DB (Pinecone) integration scaffold, for DB to be added later
- [x] Demonstrate EKS + Terraform deployment with CPU-based autoscaling
- [x] Define clear path for post-deploy improvements

---

## 2. Implementation guide
The following docs have been created as a single multi-doc implementation guide. You will update them to check off completed tasks, or add additional subtasks or details as needed.

- `1-main.md` – orchestration overview (this file)
- `2-service-mongo.md` – **service_db_api** (Mongo-backed API)
- `3-service-ai-chat.md` – **service_chat** (LLM + RAG)
- `4-infra.md` – Infra (Terraform, ECR, EKS, HPA, Make targets)
- `5-post-deploy-improvements.md` – backlog after MVP

---

## 3. High-Level Architecture

- [x] Use MongoDB Atlas in cloud (and local Mongo for development)
- [x] Implement `service_db_api`:
  - [x] Expose patient, encounter, claim, document, and chat_log endpoints
  - [x] Use shapes from `data-snippets.md`
- [x] Implement `service_chat`:
  - [x] Provide `/triage` POST endpoint
  - [x] Call `service_db_api` over HTTP to fetch **patient summary**
  - [x] Use mock LLM in MVP
  - [x] Include mock vector store + Pinecone scaffolding
  - [x] Include PHI scrub placeholder
  - [x] Include simple tracing with trace IDs
- [x] Implement Infra (EKS via Terraform):
  - [x] Two Deployments: `db-api` and `chat-api`
  - [x] HPA on CPU (target ~60%)
  - [x] ECR repos per service
  - [x] S3 + DynamoDB backend for Terraform state

---

## 4. Implementation Order

- [x] Phase 1 – Bootstrap repo and environment
  - [x] Create repo structure and top-level README
  - [x] Create `service_db_api/` and `service_chat/` directories
  - [x] Add root `Makefile` skeleton
  - [x] Add `.env.example` files for both services

- [x] Phase 2 – Implement `service_db_api` (Mongo API)
  - [x] Implement Mongo client and models
  - [x] Implement core routers (patients, encounters, claims, documents)
  - [x] Implement synthetic data scripts
  - [x] Verify `/health` and `/patients` endpoints (requires MongoDB)
  - [x] Verify `/patients/{mrn}/summary` endpoint (requires MongoDB)

- [x] Phase 3 – Implement `service_chat` (AI service)
  - [x] Implement FastAPI skeleton with `/triage` and `/health`
  - [x] Implement HTTP client to `service_db_api`
  - [x] Implement mock LLM
  - [x] Implement PHI scrub placeholder
  - [x] Implement simple tracing
  - [x] Verify `/triage` uses patient summary and mock LLM (requires both services running)

- [x] Phase 4 – Docker + Terraform (infra)
  - [x] Create Dockerfiles for both services
  - [x] Create Terraform modules for network, EKS, ECR, Mongo Atlas, and app
  - [x] Configure HPA based on CPU
  - [x] Wire env vars and K8s Secrets/ConfigMaps

- [ ] Phase 5 – Initial deploy
  - [ ] Build & push images for both services
  - [ ] Run `terraform apply` for demo environment
  - [ ] Smoke-test `/health` endpoints
  - [ ] Smoke-test `/triage` endpoint in cluster

- [ ] Phase 6 – Post-deploy improvements
  - [x] Work items tracked in `5-post-deploy-improvements.md`
  - [ ] Gradually enable Pinecone, real LLM, async ingestion, richer tracing
    - [x] Phase 1: Real LLM (Qwen3-4B-Thinking-2507) implemented
    - [ ] Phase 2: Observability & Monitoring
    - [ ] Phase 3: Load Testing
    - [ ] Additional phases per `5-post-deploy-improvements.md`

---

## 5. Top-Level Makefile Overview

- [x] Dev targets
  - [x] `make install-db-api` – install deps for `service_db_api`
  - [x] `make install-chat` – install deps for `service_chat`
  - [x] `make run-db-api` – run db API locally with uvicorn
  - [x] `make run-chat` – run chat API locally with uvicorn
  - [x] `make load-synthetic` – run Mongo synthetic data loader

- [x] Docker / Build targets
  - [x] `make docker-build-db-api`
  - [x] `make docker-build-chat`
  - [x] `make docker-push-db-api`
  - [x] `make docker-push-chat`

- [x] Infra targets
  - [x] `make tf-init`
  - [x] `make tf-plan`
  - [x] `make tf-apply`
  - [x] `make tf-destroy`

- [x] Deploy targets
  - [x] `make deploy-db-api`
  - [x] `make deploy-chat`
  - [x] `make deploy-all`

---

## 6. Validation Checklist

- [x] `service_db_api`:
  - [x] Endpoints return data aligned with `data-snippets.md`
  - [x] `/patients/{mrn}/summary` aggregates patients, encounters, claims, documents

- [x] `service_chat`:
  - [x] `/triage` accepts `patient_mrn` and `query`
  - [x] `/triage` calls `service_db_api` patient summary endpoint
  - [x] `/triage` uses mock LLM and returns a structured JSON payload
  - [x] `/triage` logs a trace ID per request

- [x] Infra:
  - [x] EKS cluster running with both Deployments healthy
  - [x] HPA objects exist and can scale pods based on CPU

- [x] Demo readiness:
  - [x] Simple runbook describing curl or HTTP sequence for demo
