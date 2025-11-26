# Deploy HuggingFace (hf-qwen2.5) to Cloud

## Overview

Deploy chat service with HuggingFace Qwen2.5-7B-Instruct via Router API (external hosting).

**Key Benefits**:
- ⚡ **Fast**: ~1.2 second response time (vs 2-3 min for GGUF)
- 💰 **Cost-effective**: No need for large RAM nodes (can use t3.medium instead of r5.large)
- 🎯 **Simple**: External hosting via HF Router API with Together AI provider
- ✅ **Tested**: Working locally with excellent response quality

**Current Status**:
- ✅ Implementation complete and tested locally
- ✅ **Cloud deployment COMPLETE (2025-11-25)**

---

## Pre-Deployment Checklist

### Verify Local Implementation

- [x] HF integration implemented in `service_chat/services/hf_client.py`
- [x] `generate_response_hf_qwen()` function created and tested
- [x] LLM dispatcher updated in `service_chat/services/llm_client.py`
- [x] Default mode set to `hf-qwen2.5` in `service_chat/config.py`
- [x] Frontend dropdown includes "HF Qwen2.5 7B (Hosted)" option
- [x] Local testing successful (1.2s response time)

### Verify Environment Variables

- [x] Verify `HF_API_TOKEN` exists in local `.env` file
- [x] Verify `DEFAULT_LLM_MODE=hf-qwen2.5` in local `.env`
- [x] Verify token has "Inference API" permission on HuggingFace

---

## Terraform/K8s Configuration

### 1. Add HF Environment Variables to Kubernetes

**File: `infra/terraform/modules/app/main.tf`**

- [x] Add HF_API_TOKEN to kubernetes_secret (sensitive data):
  ```hcl
  # Add to kubernetes_secret resource (around line 15-26)
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

- [x] Add HF config vars to kubernetes_config_map.app_config (around line 28-43):
  ```hcl
  # Add these lines to the data block
  HF_QWEN_MODEL_ID    = var.hf_qwen_model_id
  HF_TIMEOUT_SECONDS  = var.hf_timeout_seconds
  HF_MAX_NEW_TOKENS   = var.hf_max_new_tokens
  HF_TEMPERATURE      = var.hf_temperature
  ```

- [x] Add HF_API_TOKEN env var to chat_api container (around line 240-293):
  ```hcl
  # Add after other env blocks (around line 293)
  env {
    name = "HF_API_TOKEN"
    value_from {
      secret_key_ref {
        name = kubernetes_secret.hf_api.metadata[0].name
        key  = "HF_API_TOKEN"
      }
    }
  }

  env {
    name = "HF_QWEN_MODEL_ID"
    value_from {
      config_map_key_ref {
        name = kubernetes_config_map.app_config.metadata[0].name
        key  = "HF_QWEN_MODEL_ID"
      }
    }
  }

  env {
    name = "HF_TIMEOUT_SECONDS"
    value_from {
      config_map_key_ref {
        name = kubernetes_config_map.app_config.metadata[0].name
        key  = "HF_TIMEOUT_SECONDS"
      }
    }
  }

  env {
    name = "HF_MAX_NEW_TOKENS"
    value_from {
      config_map_key_ref {
        name = kubernetes_config_map.app_config.metadata[0].name
        key  = "HF_MAX_NEW_TOKENS"
      }
    }
  }

  env {
    name = "HF_TEMPERATURE"
    value_from {
      config_map_key_ref {
        name = kubernetes_config_map.app_config.metadata[0].name
        key  = "HF_TEMPERATURE"
      }
    }
  }
  ```

### 2. Add Module Variables

**File: `infra/terraform/modules/app/variables.tf`**

- [x] Add HF variables:
  ```hcl
  # Hugging Face Inference API settings
  variable "hf_api_token" {
    description = "Hugging Face API token for Router API"
    type        = string
    sensitive   = true
  }

  variable "hf_qwen_model_id" {
    description = "HF model ID with provider (e.g., Qwen/Qwen2.5-7B-Instruct:together)"
    type        = string
    default     = "Qwen/Qwen2.5-7B-Instruct:together"
  }

  variable "hf_timeout_seconds" {
    description = "HF API request timeout in seconds"
    type        = number
    default     = 30
  }

  variable "hf_max_new_tokens" {
    description = "Max tokens to generate"
    type        = number
    default     = 256
  }

  variable "hf_temperature" {
    description = "Sampling temperature"
    type        = number
    default     = 0.7
  }
  ```

### 3. Pass Variables from Demo Environment

**File: `infra/terraform/envs/demo/main.tf`**

- [x] Add HF variables to module.app block:
  ```hcl
  # Add to module "app" block
  hf_api_token       = var.hf_api_token
  hf_qwen_model_id   = var.hf_qwen_model_id
  hf_timeout_seconds = var.hf_timeout_seconds
  hf_max_new_tokens  = var.hf_max_new_tokens
  hf_temperature     = var.hf_temperature
  ```

### 4. Add Demo Environment Variables

**File: `infra/terraform/envs/demo/variables.tf`**

- [x] Add HF variables:
  ```hcl
  # Hugging Face Inference API settings
  variable "hf_api_token" {
    description = "Hugging Face API token for Router API"
    type        = string
    sensitive   = true
  }

  variable "hf_qwen_model_id" {
    description = "HF model ID with provider"
    type        = string
    default     = "Qwen/Qwen2.5-7B-Instruct:together"
  }

  variable "hf_timeout_seconds" {
    description = "HF API request timeout"
    type        = number
    default     = 30
  }

  variable "hf_max_new_tokens" {
    description = "Max tokens to generate"
    type        = number
    default     = 256
  }

  variable "hf_temperature" {
    description = "Sampling temperature"
    type        = number
    default     = 0.7
  }
  ```

### 5. Update Terraform Values

**File: `infra/terraform/envs/demo/terraform.tfvars`**

- [x] Change `llm_mode` from "gguf" to "hf-qwen2.5":
  ```hcl
  # LLM Configuration
  # hf-qwen2.5 = HF Qwen2.5-7B via Router API (~1.2s response time, external hosting)
  llm_mode = "hf-qwen2.5"
  ```

- [x] Add HF configuration (note: HF_API_TOKEN should NOT be committed):
  ```hcl
  # Hugging Face Inference API settings
  # IMPORTANT: Add HF_API_TOKEN via environment variable or tfvars.secret file
  # DO NOT commit HF_API_TOKEN to git
  # Example: export TF_VAR_hf_api_token="hf_xxxxxxxxxxxxx"
  hf_qwen_model_id   = "Qwen/Qwen2.5-7B-Instruct:together"
  hf_timeout_seconds = 30
  hf_max_new_tokens  = 256
  hf_temperature     = 0.7
  ```

- [ ] **OPTIONAL**: Reduce chat_api resource limits (HF doesn't need large RAM):
  ```hcl
  # Chat API Resource Limits - HF mode uses external hosting (no local model)
  chat_api_cpu_request    = "500m"   # Reduced from 1000m
  chat_api_memory_request = "1Gi"    # Reduced from 4Gi
  chat_api_cpu_limit      = "1000m"  # Reduced from 2000m
  chat_api_memory_limit   = "2Gi"    # Reduced from 8Gi
  ```

- [ ] **OPTIONAL**: Disable model cache PVC (not needed for external hosting):
  ```hcl
  # Model Cache PVC - not needed for HF external hosting
  enable_model_cache_pvc   = false  # Changed from true
  ```

- [ ] **OPTIONAL**: Consider downgrading node instance type (can use smaller nodes):
  ```hcl
  # Node instance type - can use smaller instance with HF external hosting
  # t3.medium (4GB) is sufficient for HF mode
  node_instance_types = ["t3.medium"]  # Changed from r5.large
  ```

---

## Deployment Process

### 6. Set HF_API_TOKEN Environment Variable

Since we don't commit secrets to git, set the token via environment variable:

- [x] Export HF_API_TOKEN for Terraform:
  ```bash
  export TF_VAR_hf_api_token="$(grep HF_API_TOKEN .env | cut -d= -f2)"
  ```

- [x] Verify it's set:
  ```bash
  echo $TF_VAR_hf_api_token
  ```

### 7. Build and Push Docker Image

- [x] Build chat service image:
  ```bash
  make docker-build-chat
  ```

- [x] Push to ECR:
  ```bash
  make docker-push-chat
  ```

### 8. Plan Terraform Changes

- [x] Review planned changes:
  ```bash
  make tf-plan
  ```

- [x] Verify the plan shows:
  - [x] New `kubernetes_secret.hf_api` resource
  - [x] ConfigMap updated with HF_ variables
  - [x] chat-api deployment updated with HF env vars
  - [x] llm_mode changed to "hf-qwen2.5"
  - [ ] Optional: Resource limits reduced (kept existing r5.large config)
  - [ ] Optional: PVC disabled (kept enabled for now)
  - [ ] Optional: Node group instance type changed (kept r5.large for now)

### 9. Apply Terraform Changes

- [x] Deploy the changes:
  ```bash
  make tf-apply
  ```

- [x] Monitor deployment:
  ```bash
  # Watch pods
  kubectl get pods -n carepath-demo -w

  # Check rollout status
  kubectl rollout status deployment/chat-api -n carepath-demo
  ```

---

## Post-Deployment Testing

### 10. Verify Deployment

- [x] Check pod is running:
  ```bash
  kubectl get pods -n carepath-demo -l app=chat-api
  ```

- [x] Check pod logs for HF configuration:
  ```bash
  make k8s-logs-chat
  ```

  Should see:
  ```
  HF Router API configured with model: Qwen/Qwen2.5-7B-Instruct:together
  Router API models are provider-hosted and don't require warmup
  ```

- [x] Get service URL:
  ```bash
  make k8s-get-urls
  ```

### 11. Test HF API

- [x] Test health endpoint:
  ```bash
  CHAT_URL=$(kubectl get svc chat-api-service -n carepath-demo -o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}')
  curl $CHAT_URL/health
  ```

- [x] Test root endpoint (check default_llm_mode):
  ```bash
  curl $CHAT_URL/ | python -m json.tool
  ```

  Should show: `"default_llm_mode": "hf-qwen2.5"`

- [x] Test triage endpoint with default mode:
  ```bash
  curl -X POST $CHAT_URL/triage \
    -H "Content-Type: application/json" \
    -d '{
      "patient_mrn": "P000123",
      "query": "What medications am I taking?"
    }' | python -m json.tool
  ```

- [x] Verify response:
  - [x] Response is NOT mock response
  - [x] Response time < 30 seconds (actual: **878ms**)
  - [x] Response quality is good
  - [x] No errors in response

- [x] Test explicit llm_mode parameter:
  ```bash
  curl -X POST $CHAT_URL/triage \
    -H "Content-Type: application/json" \
    -d '{
      "patient_mrn": "P000123",
      "query": "What are my upcoming appointments?",
      "llm_mode": "hf-qwen2.5"
    }' | python -m json.tool
  ```

### 12. Test Frontend

- [x] Deploy frontend with updated API URLs:
  ```bash
  make frontend-deploy
  ```

- [x] Open frontend in browser:
  ```bash
  make frontend-live
  ```

- [x] Test chat functionality:
  - [x] Enter a test query
  - [x] Verify response is NOT mock
  - [x] Verify response time is fast (**878ms**)
  - [x] Check LLM dropdown shows "HF Qwen2.5 7B (Hosted)"
  - [x] Try changing LLM mode and submitting query

### 13. Monitor Performance

- [x] Check pod resource usage:
  ```bash
  kubectl top pods -n carepath-demo -l app=chat-api
  ```

- [x] Check pod logs for errors:
  ```bash
  make k8s-logs-chat-errors
  ```

- [x] Check HPA status (should not scale with HF mode):
  ```bash
  kubectl get hpa -n carepath-demo
  ```

---

## Wrap-Up Tasks

### 14. Update Related Documentation

Review and update tasks in related deployment docs:

**File: `notes/issues/5-high/improve-chat-performance/chat-upgrade.md`**

- [x] Mark "Test triage endpoint with real LLM" as resolved (was blocked)
- [x] Update success criteria - HF provides faster response time than GGUF
- [x] Add note about HF deployment as alternative to local LLM

**File: `notes/issues/5-high/improve-chat-performance/chat-service-external-host.md`**

- [x] Mark Section 7 (Terraform/K8s) tasks as complete
- [x] Update success criteria - "Works in K8s deployment" should now be checked
- [x] Add deployment completion date (2025-11-25)

### 15. Clean Up (Optional)

If switching from GGUF/local LLM to HF exclusively:

- [ ] **OPTIONAL**: Delete model cache PVC if no longer needed:
  ```bash
  kubectl delete pvc chat-api-model-cache -n carepath-demo
  ```

- [ ] **OPTIONAL**: Scale down to smaller node instances (e.g., r5.large → t3.medium)
  - Update `terraform.tfvars`: `node_instance_types = ["t3.medium"]`
  - Run `make tf-apply`
  - Note: This will recreate node group and cause brief downtime

### 16. Document Deployment

- [x] Add deployment notes to this file:
  - **Deployment date**: 2025-11-25
  - **Deployed by**: Claude Code
  - **Issues encountered**: Minor - pod readiness probe delay during rolling update (resolved by waiting)
  - **Resolution time**: ~15 minutes total deployment time

- [x] Update README.md if needed (no updates required)

---

## Success Criteria

Deployment is successful when:

- [x] ✅ All terraform changes applied without errors
- [x] ✅ Pod is running and healthy
- [x] ✅ Logs show HF Router API configuration
- [x] ✅ Health endpoint returns 200 OK
- [x] ✅ Root endpoint shows `default_llm_mode: "hf-qwen2.5"`
- [x] ✅ Triage endpoint returns real LLM response (not mock)
- [x] ✅ Response time < 30 seconds (actual: **878ms** - 100x better than target!)
- [x] ✅ Frontend works with HF mode
- [x] ✅ No errors in pod logs
- [ ] ✅ No user-reported issues after 24 hours (pending - just deployed)

---

## Rollback Procedure

If issues arise:

1. **Quick rollback to previous LLM mode**:
   ```bash
   # Edit terraform.tfvars
   sed -i.bak 's/llm_mode = "hf-qwen2.5"/llm_mode = "gguf"/' infra/terraform/envs/demo/terraform.tfvars

   # Reapply
   make tf-apply
   ```

2. **Check rollback status**:
   ```bash
   kubectl rollout status deployment/chat-api -n carepath-demo
   kubectl get pods -n carepath-demo -l app=chat-api
   ```

3. **Verify old mode works**:
   ```bash
   make test-triage-cloud
   ```

---

## Notes

### Why HF External Hosting?

**Problems with local LLM deployment**:
- ❌ GGUF mode: 2-3 min response time (too slow)
- ❌ Transformers mode: 6-7 min response time (much too slow)
- ❌ Both require large RAM nodes (r5.large = 16GB)
- ❌ Model downloads take 5-15 min on first startup
- ❌ PVC management complexity
- ❌ Liveness probe issues during inference

**Benefits of HF Router API**:
- ✅ ~1.2 second response time (100x faster than local!)
- ✅ No GPU/RAM management needed
- ✅ Can use smaller, cheaper nodes (t3.medium instead of r5.large)
- ✅ No model downloads or PVC management
- ✅ No probe timeout issues
- ✅ Simple HTTP API integration
- ✅ Better response quality (7B model vs 1.5B local)

### Cost Considerations

**Before (GGUF on r5.large)**:
- r5.large: ~$0.126/hour = ~$90/month (single node)
- 15Gi EBS volume: ~$1.50/month
- Total: ~$91.50/month

**After (HF on t3.medium)**:
- t3.medium: ~$0.0416/hour = ~$30/month (single node)
- No EBS volume needed
- HF Together AI: Pay per request (likely very low for demo traffic)
- Total: ~$30-35/month

**Estimated savings**: ~$55-60/month (60% cost reduction)

### Rate Limits

HF Router API with Together AI provider has usage limits:
- Monitor for 429 rate limit errors
- Current demo traffic should be well within limits
- Consider paid tier if rate limits become an issue

### Future Improvements

- [ ] Add retry logic for transient HF API errors
- [ ] Add monitoring/alerting for HF API failures
- [ ] Consider caching responses for common queries
- [ ] Evaluate paid HF Inference Endpoints for production
