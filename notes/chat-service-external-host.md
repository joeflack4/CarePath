# External Model Hosting with Hugging Face

We have been struggling to get even a small model running on our infrastructure. We want to continue using our K8s 
infrastructure with chat service, but we need external hosting as a simpler alternative.

Our first attempt will use **Hugging Face's free Inference API**.

---

## Background: Hugging Face Free Inference API

### What It Is

Hugging Face exposes many Model Hub models via a shared, hosted **Inference API**. You call a simple HTTPS endpoint with
your model ID and access token, and they run the model on their infrastructure and return the generated text.

**Key properties:**
- **Shared, multi-tenant infrastructure** (not dedicated)
- **Good for low-volume demos and experiments**
- **Subject to rate limits, cold starts, and occasional slow/failed responses**
- **No GPU/RAM management needed**

This is different from **Inference Endpoints** (paid, dedicated deployments with SLAs).

### Why This Helps

Using the free Inference API:
- Offloads model hosting from our EKS cluster (no large RAM node needed)
- Keeps infrastructure costs lower
- Lets us focus K8s/EKS complexity on API + data services
- Still allows `mock` and `gguf` modes for testing

Reliability is "good enough" for a demo if we add warmup, timeouts, and retries.

---

## Design

### LLM Mode Name

Add a new mode: **`huggingface`** (to match the frontend dropdown we already added)

### Environment Variables

New configuration (add to `service_chat/config.py`):

- `DEFAULT_LLM_MODE` – one of: `mock`, `gguf`, `qwen`, `Qwen3-4B-Thinking-2507`, **`huggingface`**
- `HF_API_TOKEN` – Hugging Face access token with Inference API scope
- `HF_MODEL_ID` – e.g. `Qwen/Qwen2.5-1.5B-Instruct`
- `HF_TIMEOUT_SECONDS` – default: `30` (seconds)
- `HF_MAX_NEW_TOKENS` – default: `256` (max tokens to generate)
- `HF_TEMPERATURE` – default: `0.7`

These will be wired into both local `.env` and K8s ConfigMap/Secrets for the chat service.

### Request Flow

1. User sends query to `/triage` with `llm_mode=huggingface` (or uses server default)
2. Chat service calls Hugging Face Inference API with prompt
3. On success, return generated text
4. On failure (timeout, 5xx), raise HTTPException with clear error message

**No fallback to mock** - keep it simple, just fail clearly like other modes.

---

## User Tasks

### 1. Hugging Face Account & Token

- [ ] Create (or log into) a Hugging Face account at https://huggingface.co
- [ ] Go to **Settings → Access Tokens** and create a new token (needs "Inference API" permission)
- [ ] Copy token to your local `.env` as:
  ```bash
  HF_API_TOKEN=hf_xxxxxxxxxxxxx
  ```
  (Do NOT commit to git)

### 2. Model Selection

- [ ] Choose a small instruct model suitable for free inference:
  - Recommended: `Qwen/Qwen2.5-1.5B-Instruct` (fast, good quality)
  - Alternative: `HuggingFaceH4/zephyr-7b-beta` (slower, better quality)
- [ ] Test the model using the "Hosted inference API" widget on the model page to confirm it responds
- [ ] Set in your local `.env`:
  ```bash
  HF_MODEL_ID=Qwen/Qwen2.5-1.5B-Instruct
  ```

### 3. Local Testing

After implementation is complete:

- [ ] Set `DEFAULT_LLM_MODE=huggingface` in `.env`
- [ ] Restart chat service:
  ```bash
  source env/python_venv/bin/activate
  make run-chat
  ```
- [ ] Test with curl:
  ```bash
  curl -X POST http://localhost:8002/triage \
    -H "Content-Type: application/json" \
    -d '{
      "patient_mrn": "P000001",
      "query": "What medications am I taking?",
      "llm_mode": "huggingface"
    }'
  ```
- [ ] Verify:
  - Response is NOT the mock response
  - Latency is acceptable (<30s)
  - Check logs show HF API being called

### 4. K8s Deployment

After local testing passes:

- [ ] Add `HF_API_TOKEN` to AWS Secrets Manager or K8s Secret (DO NOT commit to terraform)
- [ ] Update terraform variables in `infra/terraform/envs/demo/terraform.tfvars`:
  ```hcl
  llm_mode = "huggingface"
  ```
- [ ] Deploy:
  ```bash
  make docker-build-chat
  make docker-push-chat
  make k8s-apply
  ```
- [ ] Test deployed service via frontend or curl to public URL

---

## Implementation Tasks

### 1. Configuration

**File: `service_chat/config.py`**

- [ ] Add new settings fields:
  ```python
  # Hugging Face Inference API settings
  HF_API_TOKEN: str = ""
  HF_MODEL_ID: str = "Qwen/Qwen2.5-1.5B-Instruct"
  HF_TIMEOUT_SECONDS: int = 30
  HF_MAX_NEW_TOKENS: int = 256
  HF_TEMPERATURE: float = 0.7
  ```

**File: `.env.example`**

- [ ] Update `LLM_MODE` to `DEFAULT_LLM_MODE` (fixing existing issue)
- [ ] Add HF configuration section:
  ```bash
  # Hugging Face Inference API (for DEFAULT_LLM_MODE=huggingface)
  HF_API_TOKEN=your_hf_token_here
  HF_MODEL_ID=Qwen/Qwen2.5-1.5B-Instruct
  HF_TIMEOUT_SECONDS=30
  HF_MAX_NEW_TOKENS=256
  HF_TEMPERATURE=0.7
  ```

**File: `service_chat/requirements.txt`**

- [ ] Add httpx for async HTTP calls:
  ```
  httpx>=0.27.0  # For Hugging Face API calls
  ```

### 2. Hugging Face Client

**File: `service_chat/services/hf_client.py` (NEW)**

- [ ] Create async function:
  ```python
  async def generate_response_huggingface(
      query: str,
      patient_summary: Dict[str, Any]
  ) -> str
  ```
- [ ] Build prompt using existing `rag_service.build_prompt()`
- [ ] Make POST request to:
  ```
  https://api-inference.huggingface.co/models/{HF_MODEL_ID}
  ```
- [ ] Request headers:
  ```python
  headers = {
      "Authorization": f"Bearer {settings.HF_API_TOKEN}",
      "Content-Type": "application/json"
  }
  ```
- [ ] Request body:
  ```python
  payload = {
      "inputs": prompt,
      "parameters": {
          "max_new_tokens": settings.HF_MAX_NEW_TOKENS,
          "temperature": settings.HF_TEMPERATURE,
          "return_full_text": False
      }
  }
  ```
- [ ] Handle response format (varies by model):
  - Try `response[0]["generated_text"]`
  - Fallback to raw text if array format fails
- [ ] Add timeout using `httpx.AsyncClient(timeout=settings.HF_TIMEOUT_SECONDS)`
- [ ] Log latency, status codes, model used
- [ ] On errors (timeout, 5xx, 429), raise exception with clear message

### 3. Integration with LLM Dispatcher

**File: `service_chat/services/llm_client.py`**

- [ ] Import the new function:
  ```python
  from service_chat.services.hf_client import generate_response_huggingface
  ```
- [ ] Update `generate_response()` function docstring to include `huggingface` mode
- [ ] Add new branch in dispatcher (around line 254):
  ```python
  elif mode == "huggingface":
      return await generate_response_huggingface(query, patient_summary)
  ```
- [ ] Update error message to include `huggingface` in list of valid modes

### 4. Startup Warmup (Optional but Recommended)

**File: `service_chat/main.py`**

- [ ] In the `lifespan()` context manager, add warmup for HF mode:
  ```python
  elif settings.DEFAULT_LLM_MODE == "huggingface":
      from service_chat.services.hf_client import warmup_hf_model
      warmup_hf_model()  # Sync call to wake up cold model
  ```
- [ ] Implement warmup function in `hf_client.py`:
  - Send simple request: `"test"`
  - Ignore response
  - Log success/failure
  - Do NOT block startup if warmup fails

### 5. Frontend (Already Done!)

- [x] Frontend dropdown already has "Hugging Face" option
- [ ] Verify it sends `llm_mode: "huggingface"` (check frontend code to ensure value matches)

### 6. Root Endpoint Info

**File: `service_chat/main.py`**

- [ ] Verify root `/` endpoint shows correct `default_llm_mode` (we already updated this earlier)

### 7. Terraform/K8s

**File: `infra/terraform/modules/app/main.tf`**

- [ ] Add HF_API_TOKEN to ConfigMap or Secret:
  ```hcl
  env {
    name  = "HF_API_TOKEN"
    value = var.hf_api_token  # Should come from secrets, not checked in
  }
  env {
    name  = "HF_MODEL_ID"
    value = var.hf_model_id
  }
  ```
- [ ] Add corresponding variables to module inputs
- [ ] Update `infra/terraform/envs/demo/terraform.tfvars` with values

### 8. Testing & Validation

- [ ] Test locally with `DEFAULT_LLM_MODE=huggingface`
- [ ] Test via frontend dropdown selection
- [ ] Test timeout behavior (use unrealistic 1s timeout)
- [ ] Verify logs don't leak PHI (patient_summary not logged raw)
- [ ] Test with invalid token (should fail clearly)
- [ ] Test with non-existent model ID (should fail clearly)

---

## Key Differences from Original Document

### Fixed Issues

1. ✅ **File paths corrected**: `service_chat/services/hf_client.py` (not `llm/clients/`)
2. ✅ **Dispatcher location**: `llm_client.py` (not `llm_router.py`)
3. ✅ **Startup handler**: Uses FastAPI `lifespan` context manager (not `@app.on_event`)
4. ✅ **Mode name**: `huggingface` (matches frontend, not `hf_free`)
5. ✅ **Env var name**: `DEFAULT_LLM_MODE` (we renamed from `LLM_MODE`)

### Simplified

1. ✅ **No fallback to mock** - just fail clearly like other modes
2. ✅ **No custom error classes** - use standard exceptions
3. ✅ **Simpler warmup** - just do it or don't, no optional flag
4. ✅ **Less PHI paranoia** - follow existing codebase patterns

### Added

1. ✅ **Dependency**: Add `httpx` to requirements.txt
2. ✅ **Deployment steps**: Actual commands for docker/k8s
3. ✅ **Local testing commands**: Specific curl examples
4. ✅ **Frontend note**: Already has dropdown, just verify value
5. ✅ **`.env.example` fix**: Update old `LLM_MODE` to `DEFAULT_LLM_MODE`

---

## Success Criteria

- [ ] Can select "Hugging Face" from frontend dropdown
- [ ] Query returns real LLM response (not mock)
- [ ] Response latency < 30 seconds
- [ ] Logs show HF API calls with latency metrics
- [ ] No PHI in logs
- [ ] Errors fail gracefully with clear messages
- [ ] Works both locally and in K8s deployment
