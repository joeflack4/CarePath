# CarePath AI – Multi-Service Demo (Main Orchestration Spec)

This document is the high-level “outer loop” for the project. It explains **what to build first**, how the pieces fit, and where to find detailed specs.

---

## 1. Goals

- [ ] Demonstrate backend microservices (Python + FastAPI)
- [ ] Demonstrate MongoDB modeling and APIs for healthcare-like data
- [ ] Demonstrate AI chat service using RAG over the Mongo API
- [ ] Demonstrate vector DB (Pinecone) integration scaffold, for DB to be added later
- [ ] Demonstrate EKS + Terraform deployment with CPU-based autoscaling
- [ ] Define clear path for post-deploy improvements

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

- [ ] Use MongoDB Atlas in cloud (and local Mongo for development)
- [ ] Implement `service_db_api`:
  - [ ] Expose patient, encounter, claim, document, and chat_log endpoints
  - [ ] Use shapes from `data-snippets.md`
- [ ] Implement `service_chat`:
  - [ ] Provide `/triage` POST endpoint
  - [ ] Call `service_db_api` over HTTP to fetch **patient summary**
  - [ ] Use mock LLM in MVP
  - [ ] Include mock vector store + Pinecone scaffolding
  - [ ] Include PHI scrub placeholder
  - [ ] Include simple tracing with trace IDs
- [ ] Implement Infra (EKS via Terraform):
  - [ ] Two Deployments: `db-api` and `chat-api`
  - [ ] HPA on CPU (target ~60%)
  - [ ] ECR repos per service
  - [ ] S3 + DynamoDB backend for Terraform state

---

## 4. Implementation Order

- [ ] Phase 1 – Bootstrap repo and environment
  - [ ] Create repo structure and top-level README
  - [ ] Create `service_db_api/` and `service_chat/` directories
  - [ ] Add root `Makefile` skeleton
  - [ ] Add `.env.example` files for both services

- [ ] Phase 2 – Implement `service_db_api` (Mongo API)
  - [ ] Implement Mongo client and models
  - [ ] Implement core routers (patients, encounters, claims, documents)
  - [ ] Implement synthetic data scripts
  - [ ] Verify `/health` and `/patients` endpoints
  - [ ] Verify `/patients/{mrn}/summary` endpoint

- [ ] Phase 3 – Implement `service_chat` (AI service)
  - [ ] Implement FastAPI skeleton with `/triage` and `/health`
  - [ ] Implement HTTP client to `service_db_api`
  - [ ] Implement mock LLM
  - [ ] Implement PHI scrub placeholder
  - [ ] Implement simple tracing
  - [ ] Verify `/triage` uses patient summary and mock LLM

- [ ] Phase 4 – Docker + Terraform (infra)
  - [ ] Create Dockerfiles for both services
  - [ ] Create Terraform modules for network, EKS, ECR, Mongo Atlas, and app
  - [ ] Configure HPA based on CPU
  - [ ] Wire env vars and K8s Secrets/ConfigMaps

- [ ] Phase 5 – Initial deploy
  - [ ] Build & push images for both services
  - [ ] Run `terraform apply` for demo environment
  - [ ] Smoke-test `/health` endpoints
  - [ ] Smoke-test `/triage` endpoint in cluster

- [ ] Phase 6 – Post-deploy improvements
  - [ ] Work items tracked in `5-post-deploy-improvements.md`
  - [ ] Gradually enable Pinecone, real LLM, async ingestion, richer tracing

---

## 5. Top-Level Makefile Overview

- [ ] Dev targets
  - [ ] `make install-db-api` – install deps for `service_db_api`
  - [ ] `make install-chat` – install deps for `service_chat`
  - [ ] `make run-db-api` – run db API locally with uvicorn
  - [ ] `make run-chat` – run chat API locally with uvicorn
  - [ ] `make load-synthetic` – run Mongo synthetic data loader

- [ ] Docker / Build targets
  - [ ] `make docker-build-db-api`
  - [ ] `make docker-build-chat`
  - [ ] `make docker-push-db-api`
  - [ ] `make docker-push-chat`

- [ ] Infra targets
  - [ ] `make tf-init`
  - [ ] `make tf-plan`
  - [ ] `make tf-apply`
  - [ ] `make tf-destroy`

- [ ] Deploy targets
  - [ ] `make deploy-db-api`
  - [ ] `make deploy-chat`
  - [ ] `make deploy-all`

---

## 6. Validation Checklist

- [ ] `service_db_api`:
  - [ ] Endpoints return data aligned with `data-snippets.md`
  - [ ] `/patients/{mrn}/summary` aggregates patients, encounters, claims, documents

- [ ] `service_chat`:
  - [ ] `/triage` accepts `patient_mrn` and `query`
  - [ ] `/triage` calls `service_db_api` patient summary endpoint
  - [ ] `/triage` uses mock LLM and returns a structured JSON payload
  - [ ] `/triage` logs a trace ID per request

- [ ] Infra:
  - [ ] EKS cluster running with both Deployments healthy
  - [ ] HPA objects exist and can scale pods based on CPU

- [ ] Demo readiness:
  - [ ] Simple runbook describing curl or HTTP sequence for demo
