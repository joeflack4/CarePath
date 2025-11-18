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

- [ ] At repo root, create:

  - [ ] `service_db_api/`
    - [ ] `main.py`
    - [ ] `config.py`
    - [ ] `db/`
      - [ ] `mongo.py`
    - [ ] `models/`
      - [ ] `patient.py`
      - [ ] `encounter.py`
      - [ ] `claim.py`
      - [ ] `document.py`
      - [ ] `chat_log.py`
      - [ ] `provider.py` (optional)
      - [ ] `audit_log.py` (optional)
    - [ ] `routers/`
      - [ ] `health.py`
      - [ ] `patients.py`
      - [ ] `encounters.py`
      - [ ] `claims.py`
      - [ ] `documents.py`
      - [ ] `chat_logs.py` (optional)
    - [ ] `schemas/` (optional Pydantic DTOs)
    - [ ] `__init__.py`

  - [ ] `scripts/`
    - [ ] `generate_synthetic_data.py`
    - [ ] `load_synthetic_data.py`

---

## 2. Configuration (config.py)

- [ ] Use `pydantic-settings` for environment-based config:
  - [ ] `MONGODB_URI`
  - [ ] `MONGODB_DB_NAME`
  - [ ] `API_PORT_DB_API` (e.g. 8001)
  - [ ] `LOG_LEVEL`

- [ ] Add these to root `.env.example`.

---

## 3. Mongo Client (db/mongo.py)

- [ ] Implement `MongoConnection`:
  - [ ] Holds client and database instances
  - [ ] Lazily creates `AsyncIOMotorClient` or `MongoClient`
  - [ ] Provides `get_database()` function

- [ ] Implement a `ping()` helper:
  - [ ] Issues `db.command("ping")`
  - [ ] Returns success/failure + latency

- [ ] Define collections using names from `data-snippets.md`:
  - [ ] `patients`
  - [ ] `encounters`
  - [ ] `claims`
  - [ ] `documents`
  - [ ] `chat_logs`
  - [ ] `providers`
  - [ ] `audit_logs`

- [ ] Create indexes:
  - [ ] `patients.mrn` (unique)
  - [ ] `encounters.patient_mrn`
  - [ ] `encounters.encounter_id` (unique)
  - [ ] `claims.patient_mrn`
  - [ ] `claims.claim_id` (unique)
  - [ ] `documents.doc_id` (unique)
  - [ ] `documents.patient_mrn`
  - [ ] `chat_logs.conversation_id` (unique)
  - [ ] `chat_logs.patient_mrn`
  - [ ] Optional: provider_id, event_id, timestamps

---

## 4. Routers & Endpoints

### 4.1 health.py

- [ ] `GET /health`
  - [ ] Return `{ status, service: "db-api", version }`
- [ ] `GET /health/db`
  - [ ] Call `db.command("ping")`
  - [ ] Return DB connectivity status and latency

### 4.2 patients.py

Use **patients** document shape from `data-snippets.md`.

- [ ] `GET /patients`
  - [ ] Accept `skip` (int), `limit` (int)
  - [ ] Return `{ items: [...patients], total: n }`

- [ ] `GET /patients/{mrn}`
  - [ ] Return single patient or 404

- [ ] `GET /patients/{mrn}/summary`
  - [ ] Fetch patient base record from `patients`
  - [ ] Fetch recent encounters from `encounters`
  - [ ] Fetch recent claims from `claims`
  - [ ] Fetch key documents from `documents` (e.g., care plan)
  - [ ] Combine into a structured summary JSON
  - [ ] Ensure this summary aligns with what `service_chat` needs for RAG

### 4.3 encounters.py

Use **encounters** shape from `data-snippets.md`.

- [ ] `GET /encounters`
  - [ ] Accept `skip`, `limit`, `patient_mrn` (optional)
  - [ ] Return encounters list with simple pagination

- [ ] `GET /encounters/{encounter_id}`
  - [ ] Return encounter or 404

- [ ] `GET /patients/{mrn}/encounters`
  - [ ] Return all encounters for patient, sorted by `start` descending

### 4.4 claims.py

Use **claims** shape from `data-snippets.md`.

- [ ] `GET /claims`
  - [ ] Accept `skip`, `limit`, `patient_mrn` (optional)

- [ ] `GET /claims/{claim_id}`
  - [ ] Return claim or 404

### 4.5 documents.py

Use **documents** shape from `data-snippets.md`.

- [ ] `GET /documents`
  - [ ] Accept `patient_mrn` (optional)
  - [ ] Accept `source_type` (optional)
  - [ ] Return filtered list

- [ ] `GET /documents/{doc_id}`
  - [ ] Return document or 404

- [ ] Optional: `GET /patients/{mrn}/documents`
  - [ ] Shortcut to all docs for patient

### 4.6 chat_logs.py (optional for debugging)

Use **chat_logs** shape from `data-snippets.md`.

- [ ] `GET /chat-logs`
  - [ ] Accept `patient_mrn` (optional)
- [ ] `GET /chat-logs/{conversation_id}`

---

## 5. Synthetic Data Scripts

### 5.1 generate_synthetic_data.py

- [ ] Generate JSONL files with shapes matching `data-snippets.md`:
  - [ ] `data/synthetic/patients.jsonl`
  - [ ] `data/synthetic/encounters.jsonl`
  - [ ] `data/synthetic/claims.jsonl`
  - [ ] `data/synthetic/documents.jsonl`
  - [ ] `data/synthetic/chat_logs.jsonl`
  - [ ] (Optional) providers/audit_logs JSONL files

For now, just use the same snippets in `data-snippets.md`, or something close to it. 1 record each for now is fine.

### 5.2 load_synthetic_data.py

- [ ] Read each JSONL file from `data/synthetic/`
- [ ] Connect to Mongo using `MONGODB_URI`
- [ ] Optionally drop collections before insert
- [ ] Bulk insert all documents
- [ ] Ensure indexes are (re)created

- [ ] Add root Makefile target:
  - [ ] `make load-synthetic` → `python scripts/load_synthetic_data.py`

---

## 6. service_db_api/main.py

- [ ] Create FastAPI app:
  - [ ] Title: “CarePath DB API”
  - [ ] Version: “0.1.0`

- [ ] Include routers:
  - [ ] `/health`
  - [ ] `/patients`
  - [ ] `/encounters`
  - [ ] `/claims`
  - [ ] `/documents`
  - [ ] `/chat-logs` (optional)

- [ ] Add CORS middleware for development
- [ ] On startup:
  - [ ] Initialize Mongo connection, maybe `ping()` once
- [ ] On shutdown:
  - [ ] Close Mongo connection

---

## 7. Dev Usage

- [ ] Implement `make install-db-api`:
  - [ ] Install deps (fastapi, uvicorn, motor/pymongo, pydantic-settings)

- [ ] Implement `make run-db-api`:
  - [ ] Command like: `uvicorn service_db_api.main:app --reload --port 8001`

- [ ] Verify manually:
  - [ ] `GET http://localhost:8001/health`
  - [ ] `GET http://localhost:8001/patients`
  - [ ] `GET http://localhost:8001/patients/P000123/summary`
