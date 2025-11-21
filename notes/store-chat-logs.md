# Store Chat Logs Feature

This document outlines the tasks needed to implement chat log storage, where each triage interaction (single query + 
response) is persisted to MongoDB and retrievable via the DB API.

## Overview

**Current State:**
- Chat service reads patient data from DB API but does NOT store interactions
- DB API has GET endpoints for chat_logs but NO POST endpoint
- Synthetic data shows the expected schema

**Target State:**
- Each `/triage` request creates a new chat log record
- Chat logs include: conversation metadata, messages (user query + LLM response), and retrieval events
- Retrieval events include both simple DB queries (e.g., fetch patient by MRN) and future FTS/vector searches
- Chat logs are retrievable via `/chat-logs` endpoint

**Scope:**
- Single query/response per conversation (no persistent multi-turn conversations)
- Support for simple DB retrievals in `retrieval_events` (not just FTS)
- Works locally and in deployed (EKS) environment

---

## 1. DB API: Add POST Endpoint for Chat Logs

- [x] In `service_db_api/routers/chat_logs.py`:
  - [x] Create Pydantic models for chat log creation:
    - [x] `MessageCreate` model (role, content, timestamp, model_name?, latency_ms?)
    - [x] `RetrievalEventCreate` model (step_id, query_type, query, results, latency_ms)
    - [x] `ChatLogCreate` model (patient_mrn, channel, messages, retrieval_events, trace_id)
  - [x] Add `POST /chat-logs` endpoint:
    - [x] Accept `ChatLogCreate` body
    - [x] Auto-generate `conversation_id` if not provided (format: `CONV-{date}-{patient_mrn}-{uuid_short}`)
    - [x] Auto-set `started_at` and `ended_at` timestamps
    - [x] Insert into MongoDB `chat_logs` collection
    - [x] Return created chat log with `_id` and `conversation_id`

- [x] In `service_db_api/models/` (if separate models file exists):
  - [x] Ensure chat log models match the synthetic data schema
  - [x] Support both FTS-style and simple DB query retrieval events

---

## 2. Update Retrieval Event Schema

The current synthetic data shows FTS-style retrieval. We need to support simpler DB queries too.

- [x] Define `query_type` field in retrieval events:
  - [x] `"db_query"` - Simple database query (e.g., fetch patient by MRN)
  - [x] `"fts"` - Full-text search (future)
  - [x] `"vector"` - Vector/embedding search (future, Pinecone)

- [x] Update `RetrievalEventCreate` model to support both types:
  ```python
  class RetrievalEventCreate(BaseModel):
      step_id: int
      query_type: str  # "db_query", "fts", "vector"
      query: str  # Description or actual query
      endpoint: Optional[str] = None  # e.g., "/patients/{mrn}/summary"
      latency_ms: Optional[float] = None
      results: Optional[List[dict]] = None  # For FTS/vector results
      record_count: Optional[int] = None  # For db_query results
  ```

- [ ] Update synthetic data example to show a simpler `db_query` type retrieval event

---

## 3. Chat Service: Store Interactions After Triage

- [x] In `service_chat/services/`:
  - [x] Create `chat_log_client.py`:
    - [x] `async def store_chat_log(chat_log_data: dict) -> dict`
    - [x] POST to `{DB_API_BASE_URL}/chat-logs`
    - [x] Handle errors gracefully (log but don't fail the triage response)

- [x] In `service_chat/routers/triage.py`:
  - [x] After successful LLM response, build chat log payload:
    - [x] `patient_mrn`: from request
    - [x] `trace_id`: from tracing
    - [x] `channel`: "api" (or configurable)
    - [x] `messages`: array with user query and assistant response
    - [x] `retrieval_events`: record the patient summary fetch
  - [x] Call `chat_log_client.store_chat_log()` to persist
  - [x] Include `conversation_id` in the triage response

- [x] Update `TriageResponse` model:
  - [x] Add `conversation_id: str` field

---

## 4. Track Retrieval Events in Triage Flow

- [x] In `service_chat/routers/triage.py`:
  - [x] Create a list to accumulate retrieval events during the request
  - [x] When fetching patient summary:
    - [x] Record retrieval event with:
      - `query_type`: "db_query"
      - `query`: "Fetch patient summary by MRN"
      - `endpoint`: "/patients/{mrn}/summary"
      - `latency_ms`: elapsed time
      - `record_count`: 1 (or count of returned data)
  - [ ] (Future) When doing vector search, add retrieval event with `query_type`: "vector"
  - [x] Include all retrieval events in the chat log payload

---

## 5. Infrastructure: Ensure Chat Service Can POST to DB API

- [ ] Review Terraform configuration (`infra/terraform/modules/app/main.tf`):
  - [ ] Verify chat-api can reach db-api via internal service URL
  - [ ] Current: `DB_API_BASE_URL=http://db-api-service.carepath-demo.svc.cluster.local:8001`
  - [ ] This should work for both GET and POST - no changes expected

- [ ] Verify Kubernetes network policies (if any):
  - [ ] Ensure chat-api pods can make HTTP POST requests to db-api pods

- [ ] No additional infrastructure changes should be needed (same HTTP client, same service mesh)

---

## 6. Update API Documentation

- [x] In `docs/api-db.md`:
  - [x] Add documentation for `POST /chat-logs` endpoint
  - [x] Include request body schema
  - [x] Include example curl command
  - [x] Document the `query_type` values for retrieval events

- [x] In `docs/api-chat.md`:
  - [x] Update `/triage` response to include `conversation_id`
  - [x] Note that interactions are automatically stored
  - [x] Show how to retrieve the chat log after a triage request

---

## 7. Testing

- [x] Local testing:
  - [x] Start both services locally
  - [x] Make a `/triage` request
  - [x] Verify chat log was created via `GET /chat-logs`
  - [x] Verify the retrieval event shows the patient summary fetch

- [ ] Add Makefile target for verifying chat log storage:
  - [ ] `make test-chat-log-storage` or integrate into `make test-triage`

- [ ] Update synthetic data:
  - [ ] Add a second chat log example showing `query_type: "db_query"`

---

## 8. Edge Cases and Error Handling

- [x] Handle chat log storage failures gracefully:
  - [x] If POST to `/chat-logs` fails, log the error but still return triage response
  - [x] User should get their answer even if logging fails
  - [ ] Consider retry logic or async queue (future enhancement)

- [x] Handle missing patient gracefully:
  - [x] If patient not found, don't create a chat log (or create with error status?)
  - [x] Current behavior: return 404, no chat log created

- [x] Validate chat log data before storage:
  - [x] Ensure messages array is not empty
  - [x] Ensure timestamps are valid ISO format

---

## Implementation Order

1. **DB API POST endpoint** (Section 1, 2) - Enable storage capability
2. **Chat service client** (Section 3) - Enable chat service to call POST
3. **Retrieval event tracking** (Section 4) - Capture what was retrieved
4. **Integration** (Section 3 continued) - Wire it all together in triage.py
5. **Documentation** (Section 6) - Update API docs
6. **Testing** (Section 7) - Verify end-to-end
7. **Infrastructure review** (Section 5) - Confirm no changes needed

---

## Future Enhancements (Out of Scope for MVP)

- [ ] Multi-turn conversations (multiple queries in one conversation)
- [ ] Conversation continuation (resume previous conversation)
- [ ] Vector search retrieval events (when Pinecone is integrated)
- [ ] Async chat log storage (queue-based for better performance)
- [ ] Chat log analytics and reporting
- [ ] Conversation summarization
