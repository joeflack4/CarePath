# Chat API Documentation

The `service_chat` provides an AI-powered assistant for patient healthcare questions using RAG (Retrieval Augmented Generation).

**Base URL:** `http://localhost:8002` (local development)

---

## Endpoints

- `GET /health` - Health check
- `POST /triage` - AI-powered patient assistance

## Health Endpoint

### GET /health

Basic health check to verify the service is running.

**Request:**
```bash
curl http://localhost:8002/health
```

**Response:**
```json
{
  "status": "healthy",
  "service": "service_chat"
}
```

---

## Triage Endpoint

### POST /triage

The main AI assistant endpoint. Accepts a patient MRN and a question, retrieves relevant patient data from the DB API, and generates an AI-powered response.

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `patient_mrn` | string | Yes | Patient's medical record number |
| `query` | string | Yes | The user's question about their health |

---

## Example Usage

### Using curl

**Request:**
```bash
curl -X POST http://localhost:8002/triage \
  -H "Content-Type: application/json" \
  -d '{
    "patient_mrn": "P000123",
    "query": "Why did my doctor change my diabetes medication?"
  }'
```

**Response (Mock LLM Mode):**
```json
{
  "response": "This is a mock response from the AI assistant. In production, this would be replaced with a real LLM response.",
  "trace_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "patient_mrn": "P000123",
  "llm_mode": "mock",
  "conversation_id": "CONV-2024-01-20-P000123-a1b2c3d4"
}
```

**Response (Real LLM Mode - Qwen3-4B-Thinking-2507):**
```json
{
  "response": "Based on your medical records, I can see that your doctor changed your diabetes medication during your visit on January 15, 2024. Your recent HbA1c test showed a level of 7.2%, which indicates your diabetes is reasonably well controlled. However, the medication change from Metformin 500mg to Metformin 850mg was likely made to achieve even better blood sugar control and bring your HbA1c closer to the target range of below 7%. This adjustment is a common practice when patients are tolerating their current medication well but could benefit from slightly more aggressive management. If you have concerns about this change or experience any side effects, I recommend discussing them with Dr. Sarah Chen at your next appointment.",
  "trace_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "patient_mrn": "P000123",
  "llm_mode": "Qwen3-4B-Thinking-2507",
  "conversation_id": "CONV-2024-01-20-P000123-b2c3d4e5"
}
```

---

### Using the Makefile

A convenient Makefile target is provided for testing the triage endpoint:

```bash
# Test with default query ("What are my current medications?")
make test-triage

# Test with a custom query using the 'm' parameter
make test-triage m='Why did my doctor change my diabetes medication?'

# More examples
make test-triage m='What is my diagnosis?'
make test-triage m='When is my next appointment?'
```

---

### Using Python

```python
import httpx

response = httpx.post(
    "http://localhost:8002/triage",
    json={
        "patient_mrn": "P000123",
        "query": "What are my current medications?"
    }
)

data = response.json()
print(f"Response: {data['response']}")
print(f"Trace ID: {data['trace_id']}")
```

---

## Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `response` | string | The AI-generated response to the user's query |
| `trace_id` | string | Unique identifier for request tracing and debugging |
| `patient_mrn` | string | Echo of the patient MRN from the request |
| `llm_mode` | string | The LLM mode used (`mock` or `Qwen3-4B-Thinking-2507`) |
| `conversation_id` | string | ID of the stored chat log (can be used to retrieve the interaction via `GET /chat-logs/{conversation_id}`) |

---

## Error Responses

### Patient Not Found (404)

When the specified patient MRN doesn't exist in the database.

**Request:**
```bash
curl -X POST http://localhost:8002/triage \
  -H "Content-Type: application/json" \
  -d '{
    "patient_mrn": "INVALID_MRN",
    "query": "What is my diagnosis?"
  }'
```

**Response:**
```json
{
  "detail": "Patient with MRN INVALID_MRN not found"
}
```

---

### Validation Error (422)

When the request body is missing required fields.

**Request:**
```bash
curl -X POST http://localhost:8002/triage \
  -H "Content-Type: application/json" \
  -d '{
    "patient_mrn": "P000123"
  }'
```

**Response:**
```json
{
  "detail": [
    {
      "loc": ["body", "query"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

---

### DB API Unavailable (503)

When the chat service cannot reach the database API.

**Response:**
```json
{
  "detail": "Database API service unavailable"
}
```

---

## How It Works

1. **Request Received**: The `/triage` endpoint receives a patient MRN and query
2. **Trace Started**: A unique trace ID is generated for request tracking
3. **Patient Data Fetched**: The service calls `service_db_api` to get the patient summary
4. **Prompt Built**: Patient data is formatted into a prompt context for the LLM
5. **LLM Response Generated**:
   - **Mock mode**: Returns a placeholder response (fast, for testing)
   - **Qwen mode**: Generates a real response using the Qwen3-4B model (slower, ~5-15s on CPU)
6. **Chat Log Stored**: The interaction (query + response + retrieval events) is stored to MongoDB
7. **Response Returned**: The AI response is returned with trace ID and conversation ID

---

## Retrieving Chat Logs

After a triage request, you can retrieve the stored chat log using the `conversation_id`:

```bash
# Get the specific chat log
curl http://localhost:8001/chat-logs/CONV-2024-01-20-P000123-a1b2c3d4

# List all chat logs for a patient
curl "http://localhost:8001/chat-logs?patient_mrn=P000123"
```

The chat log includes:
- The user query and AI response
- Retrieval events (what data was fetched to answer the query)
- Timestamps and latency metrics
- Trace ID for debugging

---

## Configuration

The chat service behavior is controlled by environment variables:

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_MODE` | `mock` | LLM mode (see options below) |
| `DB_API_BASE_URL` | `http://localhost:8001` | URL of the database API service |
| `MODEL_CACHE_DIR` | `./models` | Directory for downloaded models |
| `VECTOR_MODE` | `mock` | Vector DB mode (future use) |
| `LOG_LEVEL` | `INFO` | Logging verbosity |

### LLM Mode Options

| Mode | Backend | Description | Typical Latency |
|------|---------|-------------|-----------------|
| `mock` | - | Returns static test response | <100ms |
| `gguf` | llama-cpp-python | Fast quantized inference (recommended) | ~2-3 min on CPU |
| `qwen` | transformers | HuggingFace transformers | ~6-7 min on CPU |
| `Qwen3-4B-Thinking-2507` | transformers | Full model name (same as `qwen`) | ~6-7 min on CPU |

### GGUF Settings (for `LLM_MODE=gguf`)

| Variable | Default | Description |
|----------|---------|-------------|
| `GGUF_MODEL_REPO` | `Qwen/Qwen2.5-1.5B-Instruct-GGUF` | HuggingFace repo for GGUF model |
| `GGUF_MODEL_FILE` | `qwen2.5-1.5b-instruct-q4_k_m.gguf` | Specific GGUF file to download |
| `GGUF_N_CTX` | `4096` | Context window size |
| `GGUF_N_THREADS` | `4` | Number of CPU threads for inference |
| `GGUF_MAX_TOKENS` | `256` | Maximum tokens to generate |

### Example Configurations

**Fast local development (recommended):**
```bash
LLM_MODE=gguf make run-chat
```

**Testing with mock responses:**
```bash
LLM_MODE=mock make run-chat
```

**Using transformers backend:**
```bash
LLM_MODE=qwen make run-chat
# or
LLM_MODE=Qwen3-4B-Thinking-2507 make run-chat
```

**Custom GGUF model:**
```bash
GGUF_MODEL_REPO=Qwen/Qwen2.5-3B-Instruct-GGUF \
GGUF_MODEL_FILE=qwen2.5-3b-instruct-q4_k_m.gguf \
LLM_MODE=gguf make run-chat
```

---

## Tracing

Every request generates a unique `trace_id` that can be used for:
- Debugging issues in logs
- Correlating requests across services
- Performance monitoring

Search logs by trace ID:
```bash
grep "a1b2c3d4-e5f6-7890-abcd-ef1234567890" logs/*.log
```

---

## Performance Notes

| LLM Mode | Model | Typical Latency | Notes |
|----------|-------|-----------------|-------|
| `mock` | - | <100ms | For testing and development |
| `gguf` | Qwen2.5-1.5B-Instruct | ~2-3 min | Recommended for CPU inference |
| `qwen` | Qwen3-4B-Thinking | ~6-7 min | Slower, higher quality reasoning |

**Benchmark results (MacBook Pro, CPU):**
- GGUF (1.5B params, Q4_K_M): **156s** for 256 tokens
- Transformers (4B params, FP16): ~6-7 min for 128 tokens

For production deployments:
- **Recommended**: Use `gguf` mode with smaller quantized models
- Model is cached after first load
- GGUF uses Metal GPU on Mac for acceleration
- Consider GPU instances for faster inference in cloud

---

## Related Resources

- **[Database API Documentation](api-db.md)** - Data endpoints used by this service
- **[Model Management](models.md)** - How to configure and deploy LLM models
- **[AI Service Upgrade Guide](../notes/chat-upgrade.md)** - Deploying with real LLM
