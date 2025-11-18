# service_chat Spec (AI Chat + RAG + Tracing + PHI Scrub)

This service exposes an AI-powered `/triage` endpoint that:
- [ ] Receives a query and patient MRN
- [ ] Calls `service_db_api` for patient summary (RAG-lite)
- [ ] Passes combined info into an LLM interface
- [ ] Uses mock LLM and mock vector store in MVP
- [ ] Provides scaffolding for Pinecone and real model in later phases

---

## 1. Directory Layout

- [ ] Create `service_chat/`:
  - [ ] `main.py`
  - [ ] `config.py`
  - [ ] `routers/`
    - [ ] `triage.py`
    - [ ] `health.py`
  - [ ] `services/`
    - [ ] `db_client.py`         (HTTP client to `service_db_api`)
    - [ ] `llm_client.py`        (mock + future Qwen)
    - [ ] `rag_service.py`       (RAG orchestration)
    - [ ] `pinecone_client.py`   (real Pinecone SDK integration, not wired in MVP)
  - [ ] `tracing.py`             (simple trace helper)
  - [ ] `scrub_phi.py`           (PHI scrub placeholder)
  - [ ] `__init__.py`

---

## 2. Configuration (config.py)

- [ ] Use `pydantic-settings` with fields:
  - [ ] `CHAT_API_PORT` (e.g. 8002)
  - [ ] `DB_API_BASE_URL` (e.g. `http://localhost:8001`)
  - [ ] `LLM_MODE` (default `"mock"`)
  - [ ] `VECTOR_MODE` (default `"mock"`)
  - [ ] `PINECONE_API_KEY` (for future use)
  - [ ] `PINECONE_ENVIRONMENT`
  - [ ] `PINECONE_INDEX_NAME`

- [ ] Add these env vars to `.env.example`.

---

## 3. PHI Scrub Placeholder (scrub_phi.py)

- [ ] Implement function:

  - [ ] `def scrub(request_body: dict) -> dict:`
    - [ ] For MVP, return input unchanged
    - [ ] Add TODO comment for real PHI removal logic

- [ ] Ensure `/triage` calls `scrub()` before logging any request body.

---

## 4. Tracing Helper (tracing.py)

- [ ] Implement:
  - [ ] `start_trace() -> str` (returns UUID4 string)
  - [ ] `log_span(trace_id: str, span_name: str, **kwargs)`

- [ ] For MVP, log JSON-ish lines containing:
  - [ ] `trace_id`
  - [ ] `span_name`
  - [ ] Extra metadata (e.g., elapsed_ms, endpoint)

- [ ] Use spans for key points:
  - [ ] `request_received`
  - [ ] `db_api_patient_summary_start` / `end`
  - [ ] `llm_inference_start` / `end`

---

## 5. DB API Client (services/db_client.py)

- [ ] Use `httpx` or `requests` for HTTP calls
- [ ] Implement `get_patient_summary(mrn: str) -> dict`:
  - [ ] Build URL: `{DB_API_BASE_URL}/patients/{mrn}/summary`
  - [ ] Handle 404 and other errors
  - [ ] Return parsed JSON as dict

- [ ] Ensure any errors raise domain-specific exceptions for the router to catch.

---

## 6. LLM Client (services/llm_client.py)

### 6.1 Mock LLM (MVP)

- [ ] Implement function:

  - [ ] `def generate_response_mock(query: str, patient_summary: dict) -> str:`
    - [ ] Return fixed string like `"mock response"`

- [ ] Implement dispatcher:

  - [ ] `def generate_response(mode: str, query: str, patient_summary: dict) -> str:`
    - [ ] If `mode == "mock"` → use `generate_response_mock`
    - [ ] If `mode == "qwen"` → call future real model implementation

### 6.2 Qwen3-4B-Thinking-2507 (Post-deploy)

- [ ] Add placeholder for CPU-based loading of Hugging Face model
- [ ] Keep actual heavy logic specified in `5-post-deploy-improvements.md`

---

## 7. Pinecone Client (services/pinecone_client.py)

- [ ] Import real SDK:

  - [ ] `from pinecone import Pinecone`

- [ ] Implement:

  - [ ] `def get_index() -> Any:`
    - [ ] Initialize `Pinecone` client with `PINECONE_API_KEY`
    - [ ] Return `pc.Index(PINECONE_INDEX_NAME)`

  - [ ] `def query_embeddings(query_vector, top_k=5, filter=None) -> dict:`
    - [ ] Call `index.query(vector=query_vector, top_k=top_k, filter=filter)`
    - [ ] Return response

- [ ] For MVP:
  - [ ] Leave `VECTOR_MODE="mock"`
  - [ ] Do not call Pinecone from `/triage` yet
  - [ ] Document how this will be used in `5-post-deploy-improvements.md`

---

## 8. RAG Service (services/rag_service.py)

- [ ] Implement function:

  - [ ] `def build_prompt(query: str, patient_summary: dict) -> str:`
    - [ ] Format a simple text prompt:
      - [ ] Short system-style instructions
      - [ ] Patient summary block
      - [ ] User’s query

- [ ] For MVP:
  - [ ] Do not call Pinecone here
  - [ ] Only use patient summary from `service_db_api`

- [ ] Ensure this is the only place combining patient data and query into a prompt string.

---

## 9. Triage Router (routers/triage.py)

- [ ] Define request model:
  - [ ] Fields: `patient_mrn: str`, `query: str`

- [ ] `POST /triage`
  - [ ] Start trace ID
  - [ ] Run `scrub(request_body)` before logging
  - [ ] Log `request_received` span
  - [ ] Call `db_client.get_patient_summary(mrn)` with spans for start/end
  - [ ] Build prompt via `rag_service.build_prompt`
  - [ ] Call `llm_client.generate_response(LLM_MODE, query, patient_summary)`
  - [ ] Log `llm_inference` spans
  - [ ] Return JSON:
    - [ ] `trace_id`
    - [ ] `patient_mrn`
    - [ ] `query`
    - [ ] `llm_mode`
    - [ ] `response`

- [ ] Error handling:
  - [ ] If patient not found → 404 with `trace_id`
  - [ ] For other errors, log trace_id and return 500 with generic message

---

## 10. Health Router (routers/health.py)

- [ ] `GET /health`
  - [ ] Return `{ "status": "ok", "service": "chat-api", "version": "0.1.0" }`

---

## 11. service_chat/main.py

- [ ] Initialize FastAPI app:
  - [ ] Title: “CarePath Chat API”
  - [ ] Version: “0.1.0`

- [ ] Include routers:
  - [ ] `/health`
  - [ ] `/triage`

- [ ] Configure logging to include trace IDs if possible
- [ ] Add CORS for dev
- [ ] Expose app for uvicorn (`service_chat.main:app`)

---

## 12. Dev Usage

- [ ] Implement `make install-chat`:
  - [ ] Install required packages (fastapi, uvicorn, httpx, pydantic-settings, pinecone-client, etc.)

- [ ] Implement `make run-chat`:
  - [ ] Command like: `uvicorn service_chat.main:app --reload --port 8002`

- [ ] Manual test:
  - [ ] Ensure `service_db_api` is running locally
  - [ ] `POST http://localhost:8002/triage` with body:
    ```json
    {
      "patient_mrn": "P000123",
      "query": "Why did my doctor change my diabetes medication?"
    }
    ```
  - [ ] Verify response includes `trace_id` and `response: "mock response"`
