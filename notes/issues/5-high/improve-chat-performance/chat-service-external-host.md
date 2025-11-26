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

### API Migration Notice (2025)

**IMPORTANT**: Hugging Face deprecated `api-inference.huggingface.co` in favor of `router.huggingface.co`.
The free tier now has limited model availability (mostly CPU-based small models).

### LLM Mode Names

We now support **two Hugging Face hosted models**:

1. **`hf-smollm2`** - SmolLM2-1.7B-Instruct (Free HF Inference API)
   - Endpoint: `https://router.huggingface.co/hf-inference/models/HuggingFaceTB/SmolLM2-1.7B-Instruct`
   - Free tier, CPU-based, good for basic tasks

2. **`hf-qwen2.5`** - Qwen2.5-7B-Instruct (Router API with Provider)
   - Endpoint: `https://router.huggingface.co/v1/chat/completions`
   - Uses OpenAI-compatible format with provider suffix (e.g., `:together`)
   - Better quality, may have usage limits

### Environment Variables

New configuration (add to `service_chat/config.py`):

- `DEFAULT_LLM_MODE` – one of: `mock`, `gguf`, `qwen`, `Qwen3-4B-Thinking-2507`, **`hf-smollm2`**, **`hf-qwen2.5`**
- `HF_API_TOKEN` – Hugging Face access token with Inference API scope
- `HF_SMOLLM2_MODEL_ID` – default: `HuggingFaceTB/SmolLM2-1.7B-Instruct`
- `HF_QWEN_MODEL_ID` – default: `Qwen/Qwen2.5-7B-Instruct:together`
- `HF_TIMEOUT_SECONDS` – default: `30` (seconds)
- `HF_MAX_NEW_TOKENS` – default: `256` (max tokens to generate)
- `HF_TEMPERATURE` – default: `0.7`

These will be wired into both local `.env` and K8s ConfigMap/Secrets for the chat service.

### Request Flow

**For `hf-smollm2` (Free HF Inference):**
1. User sends query to `/triage` with `llm_mode=hf-smollm2`
2. Chat service calls `https://router.huggingface.co/hf-inference/models/{model_id}`
3. Uses traditional HF inference format with `inputs` and `parameters`
4. Returns generated text directly

**For `hf-qwen2.5` (Router with Provider):**
1. User sends query to `/triage` with `llm_mode=hf-qwen2.5`
2. Chat service calls `https://router.huggingface.co/v1/chat/completions`
3. Uses OpenAI-compatible format with `messages` array
4. Model ID includes provider suffix (e.g., `Qwen/Qwen2.5-7B-Instruct:together`)
5. Parses OpenAI-style response structure

**No fallback to mock** - keep it simple, just fail clearly like other modes.

---

## User Tasks

### 1. Hugging Face Account & Token

- [X] Create (or log into) a Hugging Face account at https://huggingface.co
- [X] Go to **Settings → Access Tokens** and create a new token (needs "Inference API" permission)
- [X] Copy token to your local `.env` as:
  ```bash
  HF_API_TOKEN=hf_xxxxxxxxxxxxx
  ```
  (Do NOT commit to git)

### 2. Model Selection

**UPDATE 2025**: HF deprecated old API and limited free tier models. We now support two models:

- [X] **SmolLM2-1.7B-Instruct** (Free HF Inference): `HuggingFaceTB/SmolLM2-1.7B-Instruct`
  - Free tier, CPU-based, good for basic tasks
  - Mode: `hf-smollm2`

- [X] **Qwen2.5-7B-Instruct** (Router with Provider): `Qwen/Qwen2.5-7B-Instruct:together`
  - Better quality, uses Together AI provider through HF router
  - Mode: `hf-qwen2.5`

- [X] Set in your local `.env`:
  ```bash
  HF_SMOLLM2_MODEL_ID=HuggingFaceTB/SmolLM2-1.7B-Instruct
  HF_QWEN_MODEL_ID=Qwen/Qwen2.5-7B-Instruct:together
  ```

### 3. Local Testing

After implementation is complete:

- [ ] Restart chat service:
  ```bash
  source env/python_venv/bin/activate
  make run-chat
  ```

- [ ] **Test SmolLM2 (Free HF Inference)**:
  ```bash
  curl -X POST http://localhost:8002/triage \
    -H "Content-Type: application/json" \
    -d '{
      "patient_mrn": "P000123",
      "query": "What medications am I taking?",
      "llm_mode": "hf-smollm2"
    }'
  ```

- [ ] **Test Qwen2.5 (Router with Provider)**:
  ```bash
  curl -X POST http://localhost:8002/triage \
    -H "Content-Type: application/json" \
    -d '{
      "patient_mrn": "P000123",
      "query": "What medications am I taking?",
      "llm_mode": "hf-qwen2.5"
    }'
  ```

- [ ] Verify for both:
  - Response is NOT the mock response
  - Latency is acceptable (<30s)
  - Check logs show correct HF API endpoint being called

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

- [x] ✅ **COMPLETED** - Removed SmolLM2, kept only Qwen2.5 (SmolLM2 not available on free tier):
  ```python
  # Hugging Face Inference API settings (for DEFAULT_LLM_MODE=hf-qwen2.5)
  HF_API_TOKEN: str = ""
  HF_QWEN_MODEL_ID: str = "Qwen/Qwen2.5-7B-Instruct:together"
  HF_TIMEOUT_SECONDS: int = 30
  HF_MAX_NEW_TOKENS: int = 256
  HF_TEMPERATURE: float = 0.7
  DEFAULT_LLM_MODE: str = "hf-qwen2.5"  # Set as default
  ```

**File: `.env.example`**

- [x] Update `LLM_MODE` to `DEFAULT_LLM_MODE` (fixing existing issue)
- [x] ✅ **COMPLETED** - Updated for single working model (hf-qwen2.5):
  ```bash
  # Hugging Face Inference API (for DEFAULT_LLM_MODE=hf-qwen2.5)
  DEFAULT_LLM_MODE=hf-qwen2.5  # HF Qwen2.5 via router (RECOMMENDED)
  HF_API_TOKEN=your_hf_token_here
  HF_QWEN_MODEL_ID=Qwen/Qwen2.5-7B-Instruct:together
  HF_TIMEOUT_SECONDS=30
  HF_MAX_NEW_TOKENS=256
  HF_TEMPERATURE=0.7
  ```

**File: `service_chat/requirements.txt`**

- [x] Add httpx for async HTTP calls (already installed: httpx==0.28.1)

### 2. Hugging Face Clients

**File: `service_chat/services/hf_client.py` (UPDATE)**

- [x] ~~Create SmolLM2 handler~~ - **REMOVED** (SmolLM2 not available on HF free tier - returns 404)

- [x] ✅ **COMPLETED** - Create Qwen2.5 handler `generate_response_hf_qwen()`:
  - Endpoint: `https://router.huggingface.co/v1/chat/completions`
  - Uses OpenAI-compatible format with `messages` array
  - Model ID: `Qwen/Qwen2.5-7B-Instruct:together`
  - Returns `response["choices"][0]["message"]["content"]`
  - **TESTED & WORKING** - 1.2 second response time ✅
- [x] Request headers:
  ```python
  headers = {
      "Authorization": f"Bearer {settings.HF_API_TOKEN}",
      "Content-Type": "application/json"
  }
  ```
- [x] Request body:
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
- [x] Handle response format (varies by model):
  - Try `response[0]["generated_text"]`
  - Fallback to raw text if array format fails
- [x] Add timeout using `httpx.AsyncClient(timeout=settings.HF_TIMEOUT_SECONDS)`
- [x] Log latency, status codes, model used
- [x] On errors (timeout, 5xx, 429), raise exception with clear message

### 3. Integration with LLM Dispatcher

**File: `service_chat/services/llm_client.py`**

- [x] ✅ **COMPLETED** - Import the new function (lazy import inside branch to avoid circular deps)
- [x] ✅ **COMPLETED** - Update `generate_response()` function docstring to include `hf-qwen2.5` mode
- [x] ✅ **COMPLETED** - Add new branch in dispatcher:
  ```python
  elif mode == "hf-qwen2.5":
      from service_chat.services.hf_client import generate_response_hf_qwen
      return await generate_response_hf_qwen(query, patient_summary)
  ```
- [x] ✅ **COMPLETED** - Update error message to include `hf-qwen2.5` in list of valid modes
- [x] ✅ **COMPLETED** - Removed `hf-smollm2` branch (not available)

### 4. Startup Warmup

**File: `service_chat/main.py`**

- [x] ✅ **COMPLETED** - In the `lifespan()` context manager, add warmup for HF mode:
  ```python
  elif settings.DEFAULT_LLM_MODE == "hf-qwen2.5":
      from service_chat.services.hf_client import warmup_hf_model
      warmup_hf_model()
  ```

**File: `service_chat/services/hf_client.py`**

- [x] ✅ **COMPLETED** - Simplified warmup function (no actual warmup needed for Router API):
  - Router API models are provider-hosted and ready
  - Just logs configuration info
  - First request takes 1-2 seconds

### 5. Frontend

- [x] ✅ **COMPLETED** - Updated dropdown to only show working model
- [x] ✅ **COMPLETED** - Frontend sends `llm_mode: "hf-qwen2.5"`
- [x] ✅ **COMPLETED** - Removed `hf-smollm2` option

### 6. Root Endpoint Info

**File: `service_chat/main.py`**

- [x] ✅ **COMPLETED** - Root `/` endpoint shows `default_llm_mode: "hf-qwen2.5"`

### 7. Terraform/K8s

**File: `infra/terraform/modules/app/main.tf`**

- [x] ✅ **COMPLETED 2025-11-25** - Add HF_API_TOKEN to Kubernetes Secret:
  ```hcl
  resource "kubernetes_secret" "hf_api" {
    metadata {
      name      = "hf-api-secret"
      namespace = kubernetes_namespace.carepath.metadata[0].name
    }
    data = {
      HF_API_TOKEN = var.hf_api_token
    }
    type = "Opaque"
  }
  ```
- [x] ✅ **COMPLETED** - Add HF config vars to ConfigMap (HF_QWEN_MODEL_ID, HF_TIMEOUT_SECONDS, etc.)
- [x] ✅ **COMPLETED** - Add 5 HF environment variables to chat-api container
- [x] ✅ **COMPLETED** - Add corresponding variables to module inputs (5 HF variables)
- [x] ✅ **COMPLETED** - Update `infra/terraform/envs/demo/terraform.tfvars` with HF configuration

### 8. Testing & Validation

- [x] ✅ **COMPLETED** - Test locally with `DEFAULT_LLM_MODE=hf-qwen2.5`
  - Response time: ~1.2 seconds
  - Quality: Excellent, contextual responses
  - Real LLM output (not mock)
- [x] ✅ **COMPLETED** - Test via curl with explicit `llm_mode`
- [x] ✅ **COMPLETED** - Frontend dropdown updated (shows hf-qwen2.5)
- [x] ✅ **COMPLETED** - Verified SmolLM2 not available (404 from HF free tier)
- [ ] Test timeout behavior (use unrealistic 1s timeout)
- [x] ✅ **COMPLETED** - Logs don't leak PHI (patient_summary not logged raw)
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

- [x] ✅ Can select "HF Qwen2.5 7B (Hosted)" from frontend dropdown
- [x] ✅ Query returns real LLM response (not mock) - **VERIFIED with curl**
- [x] ✅ Response latency < 30 seconds - **Actual: ~1.2 seconds**
- [x] ✅ Logs show HF Router API calls with latency metrics
- [x] ✅ No PHI in logs
- [x] ✅ Errors fail gracefully with clear messages (tested with 404)
- [x] ✅ Works in K8s deployment - **DEPLOYED 2025-11-25**

---

## Final Implementation Summary (2025-11-24)

### What Was Implemented

✅ **Working Solution**: HF Qwen2.5 7B via Router API with Together AI provider
- Mode name: `hf-qwen2.5`
- Endpoint: `https://router.huggingface.co/v1/chat/completions`
- Response time: ~1.2 seconds
- Set as default: `DEFAULT_LLM_MODE=hf-qwen2.5`

### What Was Removed

❌ **Removed**: HF SmolLM2 (free tier not available)
- Mode name: `hf-smollm2` - REMOVED from all code
- Reason: HF free tier returns 404 for SmolLM2 model
- Free tier has very limited model availability

### Status

- **Local Development**: ✅ Working perfectly
- **Cloud Deployment**: ✅ **DEPLOYED 2025-11-25**
  - Terraform configured with HF_API_TOKEN via environment variable
  - Kubernetes Secret created for sensitive token
  - ConfigMap updated with HF configuration
  - Pod running and serving requests successfully
  - Response time: ~878ms (0.9 seconds)
  - See `notes/deploy-hf.md` for complete deployment documentation
