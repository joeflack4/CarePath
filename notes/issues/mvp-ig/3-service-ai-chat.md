# service_chat Spec (AI Chat + RAG + Tracing + PHI Scrub)

This service exposes an AI-powered `/triage` endpoint that:
- [x] Receives a query and patient MRN
- [x] Calls `service_db_api` for patient summary (RAG-lite)
- [x] Passes combined info into an LLM interface
- [x] Uses mock LLM and mock vector store in MVP
- [x] Provides scaffolding for Pinecone and real model in later phases

---

## 1. Directory Layout

- [x] Create `service_chat/`:
  - [x] `main.py`
  - [x] `config.py`
  - [x] `routers/`
    - [x] `triage.py`
    - [x] `health.py`
  - [x] `services/`
    - [x] `db_client.py`         (HTTP client to `service_db_api`)
    - [x] `llm_client.py`        (mock + future Qwen)
    - [x] `rag_service.py`       (RAG orchestration)
    - [x] `pinecone_client.py`   (real Pinecone SDK integration, not wired in MVP)
  - [x] `tracing.py`             (simple trace helper)
  - [x] `scrub_phi.py`           (PHI scrub placeholder)
  - [x] `__init__.py`

---

## 2. Configuration (config.py)

- [x] Use `pydantic-settings` with fields:
  - [x] `CHAT_API_PORT` (e.g. 8002)
  - [x] `DB_API_BASE_URL` (e.g. `http://localhost:8001`)
  - [x] `LLM_MODE` (default `"mock"`)
  - [x] `VECTOR_MODE` (default `"mock"`)
  - [x] `PINECONE_API_KEY` (for future use)
  - [x] `PINECONE_ENVIRONMENT`
  - [x] `PINECONE_INDEX_NAME`

- [x] Add these env vars to `.env.example`.

---

## 3. PHI Scrub Placeholder (scrub_phi.py)

- [x] Implement function:

  - [x] `def scrub(request_body: dict) -> dict:`
    - [x] For MVP, return input unchanged
    - [x] Add TODO comment for real PHI removal logic

- [x] Ensure `/triage` calls `scrub()` before logging any request body.

---

## 4. Tracing Helper (tracing.py)

- [x] Implement:
  - [x] `start_trace() -> str` (returns UUID4 string)
  - [x] `log_span(trace_id: str, span_name: str, **kwargs)`

- [x] For MVP, log JSON-ish lines containing:
  - [x] `trace_id`
  - [x] `span_name`
  - [x] Extra metadata (e.g., elapsed_ms, endpoint)

- [x] Use spans for key points:
  - [x] `request_received`
  - [x] `db_api_patient_summary_start` / `end`
  - [x] `llm_inference_start` / `end`

---

## 5. DB API Client (services/db_client.py)

- [x] Use `httpx` or `requests` for HTTP calls
- [x] Implement `get_patient_summary(mrn: str) -> dict`:
  - [x] Build URL: `{DB_API_BASE_URL}/patients/{mrn}/summary`
  - [x] Handle 404 and other errors
  - [x] Return parsed JSON as dict

- [x] Ensure any errors raise domain-specific exceptions for the router to catch.

---

## 6. LLM Client (services/llm_client.py)

### 6.1 Mock LLM (MVP)

- [x] Implement function:

  - [x] `def generate_response_mock(query: str, patient_summary: dict) -> str:`
    - [x] Return fixed string like `"mock response"`

- [x] Implement dispatcher:

  - [x] `def generate_response(mode: str, query: str, patient_summary: dict) -> str:`
    - [x] If `mode == "mock"` → use `generate_response_mock`
    - [x] If `mode == "qwen"` → call future real model implementation

### 6.2 Qwen3-4B-Thinking-2507 (Post-deploy)

- [x] Add placeholder for CPU-based loading of Hugging Face model
- [x] Keep actual heavy logic specified in `5-post-deploy-improvements.md`

---

## 7. Pinecone Client (services/pinecone_client.py)

- [x] Import real SDK:

  - [x] `from pinecone import Pinecone` (commented out, scaffold only)

- [x] Implement:

  - [x] `def get_index() -> Any:` (scaffold with NotImplementedError)
    - [ ] Initialize `Pinecone` client with `PINECONE_API_KEY` (future work)
    - [ ] Return `pc.Index(PINECONE_INDEX_NAME)` (future work)

  - [x] `def query_embeddings(query_vector, top_k=5, filter=None) -> dict:` (scaffold with NotImplementedError)
    - [ ] Call `index.query(vector=query_vector, top_k=top_k, filter=filter)` (future work)
    - [ ] Return response (future work)

- [x] For MVP:
  - [x] Leave `VECTOR_MODE="mock"`
  - [x] Do not call Pinecone from `/triage` yet
  - [x] Document how this will be used in `5-post-deploy-improvements.md`

---

## 8. RAG Service (services/rag_service.py)

- [x] Implement function:

  - [x] `def build_prompt(query: str, patient_summary: dict) -> str:`
    - [x] Format a simple text prompt:
      - [x] Short system-style instructions
      - [x] Patient summary block
      - [x] User's query

- [x] For MVP:
  - [x] Do not call Pinecone here
  - [x] Only use patient summary from `service_db_api`

- [x] Ensure this is the only place combining patient data and query into a prompt string.

---

## 9. Triage Router (routers/triage.py)

- [x] Define request model:
  - [x] Fields: `patient_mrn: str`, `query: str`

- [x] `POST /triage`
  - [x] Start trace ID
  - [x] Run `scrub(request_body)` before logging
  - [x] Log `request_received` span
  - [x] Call `db_client.get_patient_summary(mrn)` with spans for start/end
  - [x] Build prompt via `rag_service.build_prompt`
  - [x] Call `llm_client.generate_response(LLM_MODE, query, patient_summary)`
  - [x] Log `llm_inference` spans
  - [x] Return JSON:
    - [x] `trace_id`
    - [x] `patient_mrn`
    - [x] `query`
    - [x] `llm_mode`
    - [x] `response`

- [x] Error handling:
  - [x] If patient not found → 404 with `trace_id`
  - [x] For other errors, log trace_id and return 500 with generic message

---

## 10. Health Router (routers/health.py)

- [x] `GET /health`
  - [x] Return `{ "status": "ok", "service": "chat-api", "version": "0.1.0" }`

---

## 11. service_chat/main.py

- [x] Initialize FastAPI app:
  - [x] Title: "CarePath Chat API"
  - [x] Version: "0.1.0`

- [x] Include routers:
  - [x] `/health`
  - [x] `/triage`

- [x] Configure logging to include trace IDs if possible
- [x] Add CORS for dev
- [x] Expose app for uvicorn (`service_chat.main:app`)

---

## 12. Dev Usage

- [x] Implement `make install-chat`:
  - [x] Install required packages (fastapi, uvicorn, httpx, pydantic-settings, pinecone-client, etc.)

- [x] Implement `make run-chat`:
  - [x] Command like: `uvicorn service_chat.main:app --reload --port 8002`

- [ ] Manual test (for user to complete):
  - [ ] Ensure `service_db_api` is running locally
  - [ ] `POST http://localhost:8002/triage` with body:
    ```json
    {
      "patient_mrn": "P000123",
      "query": "Why did my doctor change my diabetes medication?"
    }
    ```
  - [ ] Verify response includes `trace_id` and `response: "mock response"`
