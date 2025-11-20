# service_db_api Spec (Mongo-backed Data Service)

This file defines the FastAPI microservice that exposes healthcare-like data from MongoDB. It drives both the standalone demo and the RAG context for `service_chat`.

Refer explicitly to **`data-snippets.md`** for sample document shapes:
- [ ] patients
- [ ] encounters
- [ ] claims
- [ ] documents
- [ ] chat_logs
- [ ] providers (optional)
- [ ] audit_logs (optional)

---

## 1. Directory Layout

- [x] At repo root, create:

  - [x] `service_db_api/`
    - [x] `main.py`
    - [x] `config.py`
    - [x] `db/`
      - [x] `mongo.py`
    - [x] `models/`
      - [x] `patient.py`
      - [x] `encounter.py`
      - [x] `claim.py`
      - [x] `document.py`
      - [x] `chat_log.py`
      - [x] `provider.py` (optional)
      - [x] `audit_log.py` (optional)
    - [x] `routers/`
      - [x] `health.py`
      - [x] `patients.py`
      - [x] `encounters.py`
      - [x] `claims.py`
      - [x] `documents.py`
      - [x] `chat_logs.py` (optional)
    - [x] `schemas/` (optional Pydantic DTOs)
    - [x] `__init__.py`

  - [x] `scripts/`
    - [x] `generate_synthetic_data.py`
    - [x] `load_synthetic_data.py`

---

## 2. Configuration (config.py)

- [x] Use `pydantic-settings` for environment-based config:
  - [x] `MONGODB_URI`
  - [x] `MONGODB_DB_NAME`
  - [x] `API_PORT_DB_API` (e.g. 8001)
  - [x] `LOG_LEVEL`

- [x] Add these to root `.env.example`.

---

## 3. Mongo Client (db/mongo.py)

- [x] Implement `MongoConnection`:
  - [x] Holds client and database instances
  - [x] Lazily creates `AsyncIOMotorClient` or `MongoClient`
  - [x] Provides `get_database()` function

- [x] Implement a `ping()` helper:
  - [x] Issues `db.command("ping")`
  - [x] Returns success/failure + latency

- [x] Define collections using names from `data-snippets.md`:
  - [x] `patients`
  - [x] `encounters`
  - [x] `claims`
  - [x] `documents`
  - [x] `chat_logs`
  - [x] `providers`
  - [x] `audit_logs`

- [x] Create indexes:
  - [x] `patients.mrn` (unique)
  - [x] `encounters.patient_mrn`
  - [x] `encounters.encounter_id` (unique)
  - [x] `claims.patient_mrn`
  - [x] `claims.claim_id` (unique)
  - [x] `documents.doc_id` (unique)
  - [x] `documents.patient_mrn`
  - [x] `chat_logs.conversation_id` (unique)
  - [x] `chat_logs.patient_mrn`
  - [x] Optional: provider_id, event_id, timestamps

---

## 4. Routers & Endpoints

### 4.1 health.py

- [x] `GET /health`
  - [x] Return `{ status, service: "db-api", version }`
- [x] `GET /health/db`
  - [x] Call `db.command("ping")`
  - [x] Return DB connectivity status and latency

### 4.2 patients.py

Use **patients** document shape from `data-snippets.md`.

- [x] `GET /patients`
  - [x] Accept `skip` (int), `limit` (int)
  - [x] Return `{ items: [...patients], total: n }`

- [x] `GET /patients/{mrn}`
  - [x] Return single patient or 404

- [x] `GET /patients/{mrn}/summary`
  - [x] Fetch patient base record from `patients`
  - [x] Fetch recent encounters from `encounters`
  - [x] Fetch recent claims from `claims`
  - [x] Fetch key documents from `documents` (e.g., care plan)
  - [x] Combine into a structured summary JSON
  - [x] Ensure this summary aligns with what `service_chat` needs for RAG

### 4.3 encounters.py

Use **encounters** shape from `data-snippets.md`.

- [x] `GET /encounters`
  - [x] Accept `skip`, `limit`, `patient_mrn` (optional)
  - [x] Return encounters list with simple pagination

- [x] `GET /encounters/{encounter_id}`
  - [x] Return encounter or 404

- [x] `GET /patients/{mrn}/encounters`
  - [x] Return all encounters for patient, sorted by `start` descending

### 4.4 claims.py

Use **claims** shape from `data-snippets.md`.

- [x] `GET /claims`
  - [x] Accept `skip`, `limit`, `patient_mrn` (optional)

- [x] `GET /claims/{claim_id}`
  - [x] Return claim or 404

### 4.5 documents.py

Use **documents** shape from `data-snippets.md`.

- [x] `GET /documents`
  - [x] Accept `patient_mrn` (optional)
  - [x] Accept `source_type` (optional)
  - [x] Return filtered list

- [x] `GET /documents/{doc_id}`
  - [x] Return document or 404

- [x] Optional: `GET /patients/{mrn}/documents`
  - [x] Shortcut to all docs for patient

### 4.6 chat_logs.py (optional for debugging)

Use **chat_logs** shape from `data-snippets.md`.

- [x] `GET /chat-logs`
  - [x] Accept `patient_mrn` (optional)
- [x] `GET /chat-logs/{conversation_id}`

---

## 5. Synthetic Data Scripts

### 5.1 generate_synthetic_data.py

- [x] Generate JSONL files with shapes matching `data-snippets.md`:
  - [x] `data/synthetic/patients.jsonl`
  - [x] `data/synthetic/encounters.jsonl`
  - [x] `data/synthetic/claims.jsonl`
  - [x] `data/synthetic/documents.jsonl`
  - [x] `data/synthetic/chat_logs.jsonl`
  - [x] (Optional) providers/audit_logs JSONL files

For now, just use the same snippets in `data-snippets.md`, or something close to it. 1 record each for now is fine.

### 5.2 load_synthetic_data.py

- [x] Read each JSONL file from `data/synthetic/`
- [x] Connect to Mongo using `MONGODB_URI`
- [x] Optionally drop collections before insert
- [x] Bulk insert all documents
- [x] Ensure indexes are (re)created

- [x] Add root Makefile target:
  - [x] `make load-synthetic` → `python scripts/load_synthetic_data.py`

---

## 6. service_db_api/main.py

- [x] Create FastAPI app:
  - [x] Title: "CarePath DB API"
  - [x] Version: "0.1.0`

- [x] Include routers:
  - [x] `/health`
  - [x] `/patients`
  - [x] `/encounters`
  - [x] `/claims`
  - [x] `/documents`
  - [x] `/chat-logs` (optional)

- [x] Add CORS middleware for development
- [x] On startup:
  - [x] Initialize Mongo connection, maybe `ping()` once
- [x] On shutdown:
  - [x] Close Mongo connection

---

## 7. Dev Usage

- [x] Implement `make install-db-api`:
  - [x] Install deps (fastapi, uvicorn, motor/pymongo, pydantic-settings)

- [x] Implement `make run-db-api`:
  - [x] Command like: `uvicorn service_db_api.main:app --reload --port 8001`

- [ ] Verify manually (requires MongoDB running):
  - [ ] `GET http://localhost:8001/health`
  - [ ] `GET http://localhost:8001/patients`
  - [ ] `GET http://localhost:8001/patients/P000123/summary`
