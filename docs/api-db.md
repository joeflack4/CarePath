# Database API Documentation

The `service_db_api` provides a RESTful API for accessing healthcare data stored in MongoDB.

**Base URL:** `http://localhost:8001` (local development)

---

## Endpoints

- `GET /health` - Health check
- `GET /health/db` - Database connectivity check
- `GET /patients` - List patients (paginated)
- `GET /patients/{mrn}` - Get patient by MRN
- `GET /patients/{mrn}/summary` - Get comprehensive patient summary
- `GET /encounters` - List encounters
- `GET /claims` - List claims
- `GET /documents` - List documents
- `GET /chat-logs` - List chat logs

## Health Endpoints

### GET /health

Basic health check to verify the service is running.

**Request:**
```bash
curl http://localhost:8001/health
```

**Response:**
```json
{
  "status": "healthy",
  "service": "service_db_api"
}
```

---

### GET /health/db

Database connectivity check to verify MongoDB connection.

**Request:**
```bash
curl http://localhost:8001/health/db
```

**Response (Success):**
```json
{
  "status": "healthy",
  "database": "connected"
}
```

**Response (Failure):**
```json
{
  "status": "unhealthy",
  "database": "disconnected",
  "error": "Connection refused"
}
```

---

## Patient Endpoints

### GET /patients

List all patients with pagination.

**Query Parameters:**
- `skip` (int, optional): Number of records to skip (default: 0)
- `limit` (int, optional): Maximum records to return (default: 100)

**Request:**
```bash
curl "http://localhost:8001/patients?skip=0&limit=10"
```

**Response:**
```json
[
  {
    "_id": "683d8f1e2a4b5c6d7e8f9a0b",
    "mrn": "P000123",
    "name": {
      "first": "Maria",
      "last": "Garcia"
    },
    "dob": "1985-03-15",
    "gender": "female",
    "address": {
      "street": "456 Oak Ave",
      "city": "Austin",
      "state": "TX",
      "zip": "78701"
    },
    "conditions": [
      {
        "code": "E11.9",
        "display": "Type 2 diabetes mellitus without complications",
        "onset": "2018-06-01"
      }
    ],
    "medications": [
      {
        "name": "Metformin",
        "dose": "500mg",
        "frequency": "twice daily",
        "start_date": "2018-06-15"
      }
    ],
    "allergies": [
      {
        "substance": "Penicillin",
        "reaction": "Rash",
        "severity": "moderate"
      }
    ]
  }
]
```

---

### GET /patients/{mrn}

Get a single patient by Medical Record Number (MRN).

**Path Parameters:**
- `mrn` (string, required): Patient's medical record number

**Request:**
```bash
curl http://localhost:8001/patients/P000123
```

**Response:**
```json
{
  "_id": "683d8f1e2a4b5c6d7e8f9a0b",
  "mrn": "P000123",
  "name": {
    "first": "Maria",
    "last": "Garcia"
  },
  "dob": "1985-03-15",
  "gender": "female",
  "conditions": [...],
  "medications": [...],
  "allergies": [...]
}
```

**Error Response (404):**
```json
{
  "detail": "Patient not found"
}
```

---

### GET /patients/{mrn}/summary

Get a comprehensive patient summary including related encounters, claims, and documents. This endpoint is used by the chat service for RAG context.

**Path Parameters:**
- `mrn` (string, required): Patient's medical record number

**Request:**
```bash
curl http://localhost:8001/patients/P000123/summary
```

**Response:**
```json
{
  "patient": {
    "mrn": "P000123",
    "name": {
      "first": "Maria",
      "last": "Garcia"
    },
    "dob": "1985-03-15",
    "gender": "female",
    "conditions": [
      {
        "code": "E11.9",
        "display": "Type 2 diabetes mellitus without complications",
        "onset": "2018-06-01"
      }
    ],
    "medications": [
      {
        "name": "Metformin",
        "dose": "500mg",
        "frequency": "twice daily"
      }
    ],
    "allergies": [
      {
        "substance": "Penicillin",
        "reaction": "Rash"
      }
    ]
  },
  "recent_encounters": [
    {
      "encounter_id": "ENC-20240115-001",
      "type": "office_visit",
      "start": "2024-01-15T09:00:00Z",
      "end": "2024-01-15T09:30:00Z",
      "reason": "Diabetes follow-up",
      "provider": {
        "name": "Dr. Sarah Chen",
        "specialty": "Internal Medicine"
      },
      "diagnoses": [
        {
          "code": "E11.9",
          "display": "Type 2 diabetes mellitus"
        }
      ]
    }
  ],
  "recent_claims": [
    {
      "claim_id": "CLM-2024-00456",
      "service_date": "2024-01-15",
      "total_amount": 150.00,
      "status": "paid"
    }
  ],
  "recent_documents": [
    {
      "doc_id": "DOC-2024-00789",
      "type": "lab_result",
      "title": "HbA1c Test Results",
      "date": "2024-01-15",
      "summary": "HbA1c: 7.2% - Well controlled"
    }
  ]
}
```

---

## Encounter Endpoints

### GET /encounters

List all encounters with optional filtering and pagination.

**Query Parameters:**
- `patient_mrn` (string, optional): Filter by patient MRN
- `skip` (int, optional): Number of records to skip (default: 0)
- `limit` (int, optional): Maximum records to return (default: 100)

**Request:**
```bash
# All encounters
curl "http://localhost:8001/encounters?limit=10"

# Encounters for specific patient
curl "http://localhost:8001/encounters?patient_mrn=P000123"
```

**Response:**
```json
[
  {
    "_id": "683d8f1e2a4b5c6d7e8f9a0c",
    "encounter_id": "ENC-20240115-001",
    "patient_mrn": "P000123",
    "type": "office_visit",
    "start": "2024-01-15T09:00:00Z",
    "end": "2024-01-15T09:30:00Z",
    "reason": "Diabetes follow-up",
    "provider": {
      "name": "Dr. Sarah Chen",
      "npi": "1234567890",
      "specialty": "Internal Medicine"
    },
    "diagnoses": [
      {
        "code": "E11.9",
        "display": "Type 2 diabetes mellitus without complications"
      }
    ],
    "procedures": [],
    "notes": "Patient reports good medication adherence. Blood sugar levels stable."
  }
]
```

---

## Claims Endpoints

### GET /claims

List all claims with optional filtering and pagination.

**Query Parameters:**
- `patient_mrn` (string, optional): Filter by patient MRN
- `skip` (int, optional): Number of records to skip (default: 0)
- `limit` (int, optional): Maximum records to return (default: 100)

**Request:**
```bash
curl "http://localhost:8001/claims?patient_mrn=P000123"
```

**Response:**
```json
[
  {
    "_id": "683d8f1e2a4b5c6d7e8f9a0d",
    "claim_id": "CLM-2024-00456",
    "patient_mrn": "P000123",
    "encounter_id": "ENC-20240115-001",
    "service_date": "2024-01-15",
    "provider_npi": "1234567890",
    "diagnosis_codes": ["E11.9"],
    "procedure_codes": ["99213"],
    "total_amount": 150.00,
    "allowed_amount": 120.00,
    "patient_responsibility": 30.00,
    "status": "paid",
    "payer": "Blue Cross Blue Shield"
  }
]
```

---

## Document Endpoints

### GET /documents

List all documents with optional filtering and pagination.

**Query Parameters:**
- `patient_mrn` (string, optional): Filter by patient MRN
- `doc_type` (string, optional): Filter by document type
- `skip` (int, optional): Number of records to skip (default: 0)
- `limit` (int, optional): Maximum records to return (default: 100)

**Request:**
```bash
curl "http://localhost:8001/documents?patient_mrn=P000123&doc_type=lab_result"
```

**Response:**
```json
[
  {
    "_id": "683d8f1e2a4b5c6d7e8f9a0e",
    "doc_id": "DOC-2024-00789",
    "patient_mrn": "P000123",
    "encounter_id": "ENC-20240115-001",
    "type": "lab_result",
    "title": "HbA1c Test Results",
    "date": "2024-01-15",
    "author": "Quest Diagnostics",
    "content": "Hemoglobin A1c (HbA1c): 7.2%\nReference Range: <5.7% (Normal), 5.7-6.4% (Prediabetes), >=6.5% (Diabetes)\nInterpretation: Patient's diabetes is well controlled.",
    "summary": "HbA1c: 7.2% - Well controlled"
  }
]
```

---

## Chat Log Endpoints

### POST /chat-logs

Create a new chat log entry. This endpoint is used by the chat service to store triage interactions.

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `patient_mrn` | string | Yes | Patient's medical record number |
| `channel` | string | No | Channel identifier (default: "api") |
| `messages` | array | Yes | Array of message objects |
| `retrieval_events` | array | No | Array of retrieval event objects |
| `trace_id` | string | No | Trace ID for request correlation |
| `conversation_id` | string | No | Custom conversation ID (auto-generated if not provided) |

**Message Object:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `role` | string | Yes | "user" or "assistant" |
| `content` | string | Yes | Message content |
| `timestamp` | string | No | ISO timestamp (auto-set if not provided) |
| `model_name` | string | No | LLM model name (for assistant messages) |
| `latency_ms` | float | No | Response latency (for assistant messages) |

**Retrieval Event Object:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `step_id` | int | Yes | Sequential step number |
| `query_type` | string | Yes | "db_query", "fts", or "vector" |
| `query` | string | Yes | Description or actual query |
| `endpoint` | string | No | API endpoint called |
| `latency_ms` | float | No | Query latency |
| `results` | array | No | For FTS/vector search results |
| `record_count` | int | No | For db_query result counts |

**Request:**
```bash
curl -X POST http://localhost:8001/chat-logs \
  -H "Content-Type: application/json" \
  -d '{
    "patient_mrn": "P000123",
    "channel": "api",
    "messages": [
      {
        "role": "user",
        "content": "What are my current medications?"
      },
      {
        "role": "assistant",
        "content": "Based on your records, you are currently taking Metformin 500mg twice daily.",
        "model_name": "mock",
        "latency_ms": 150
      }
    ],
    "retrieval_events": [
      {
        "step_id": 1,
        "query_type": "db_query",
        "query": "Fetch patient summary by MRN",
        "endpoint": "/patients/P000123/summary",
        "latency_ms": 45.2,
        "record_count": 1
      }
    ],
    "trace_id": "abc123-def456"
  }'
```

**Response (201 Created):**
```json
{
  "_id": "683d8f1e2a4b5c6d7e8f9a10",
  "conversation_id": "CONV-2024-01-20-P000123-a1b2c3d4",
  "patient_mrn": "P000123",
  "channel": "api",
  "started_at": "2024-01-20T14:30:00.000Z",
  "ended_at": "2024-01-20T14:30:00.000Z",
  "messages": [...],
  "retrieval_events": [...],
  "trace_id": "abc123-def456"
}
```

---

### GET /chat-logs

List chat conversation logs with optional filtering.

**Query Parameters:**
- `patient_mrn` (string, optional): Filter by patient MRN
- `skip` (int, optional): Number of records to skip (default: 0)
- `limit` (int, optional): Maximum records to return (default: 100)

**Request:**
```bash
curl "http://localhost:8001/chat-logs?patient_mrn=P000123"
```

**Response:**
```json
[
  {
    "_id": "683d8f1e2a4b5c6d7e8f9a0f",
    "conversation_id": "CONV-2024-00123",
    "patient_mrn": "P000123",
    "started_at": "2024-01-20T14:30:00Z",
    "messages": [
      {
        "role": "user",
        "content": "Why was my medication changed?",
        "timestamp": "2024-01-20T14:30:00Z"
      },
      {
        "role": "assistant",
        "content": "Based on your recent lab results...",
        "timestamp": "2024-01-20T14:30:05Z"
      }
    ],
    "trace_id": "abc123-def456-ghi789"
  }
]
```

---

## Error Responses

All endpoints may return standard HTTP error responses:

| Status Code | Description |
|-------------|-------------|
| 400 | Bad Request - Invalid parameters |
| 404 | Not Found - Resource doesn't exist |
| 500 | Internal Server Error - Database or service error |

**Example Error Response:**
```json
{
  "detail": "Error message describing the issue"
}
```

---

## Related Resources

- **[Chat API Documentation](api-chat.md)** - AI assistant endpoints
- **[Model Management](models.md)** - LLM configuration
