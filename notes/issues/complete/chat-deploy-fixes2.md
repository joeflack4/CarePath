# Chat Service Deployment Issues - Session 2

**Date**: 2024-11-24
**Context**: After successfully deploying GGUF model, discovered multiple issues during frontend testing

## Session 3 Summary (2024-11-24 Evening)

**Status**: ✅ All diagnostic fixes deployed, ready for testing

**What We Fixed**:
1. ✅ Added detailed inference timing logs (thread name, model load, prompt build, inference duration)
2. ✅ Fixed uvicorn timestamp logging (access logs now have timestamps)
3. ✅ Fixed Makefile `k8s-get-urls` to show DB API is publicly accessible
4. ✅ Deployed new image with all improvements

**Current State**:
- Pod: `chat-api-d67c5c766-474l9` running with new code
- Model loaded from PVC in 0.6s (persistent disk cache working)
- Health checks now every 2 minutes (was every 5 seconds)
- Liveness probe: 120s period, 180s timeout, 20 failures = 40 min grace
- Load balancer timeout: 600s (10 minutes)

**Next Step**: User to test query from frontend. New logs will show exactly where time is spent during inference.

**Known Issue**: Inference still expected to be slow (7+ minutes) on r5.large CPU. Recommend upgrading to c6i.xlarge for 4-8x speedup ($32/mo increase).

---

## Issue Summary

### 1. First Request Times Out After 3-5 Minutes
**Status**: 🔴 Critical

**Observed Behavior**:
- Frontend query to `/triage` endpoint takes 3-5 minutes before failing
- Locally, first response takes ~2 minutes, subsequent responses 5-30 seconds
- In cloud, the request never completes

**Error in Frontend**:
```
POST http://a69d9c05b20574b299c492754bd57f96-1048466232.us-east-2.elb.amazonaws.com/triage
net::ERR_EMPTY_RESPONSE
```

**Last Log Entry Before Failure**:
```
2025-11-24 20:00:47,138 - service_chat.tracing - INFO - {"trace_id": "0bca65f9-b22a-4305-ac2f-6d4383d6047b", "span_name": "llm_inference_start", "llm_mode": "gguf"}
2025-11-24 20:00:47,138 - service_chat.services.llm_client - INFO - Using cached llama.cpp model
2025-11-24 20:00:47,139 - service_chat.services.llm_client - INFO - Generating response with llama.cpp GGUF model (max_tokens=256)...
```

**No completion log** - inference never finished or pod restarted

---

### 2. Pod Appears to Have Restarted Mid-Request
**Status**: 🔴 Critical

**Observed Behavior**:
- After the failed request, checking logs shows pod startup sequence
- Previous query logs are missing
- Only shows:
  ```
  INFO:     Started server process [1]
  INFO:     Waiting for application startup.
  2025-11-24 20:01:50,931 - service_chat.main - INFO - Starting eager model loading...
  ```

**Questions**:
- Did the pod restart during inference?
- Was it killed by OOM or timeout?
- Are logs being lost?

**Potential Causes**:
- Pod OOM killed during inference
- Liveness probe killed the pod
- Request timeout from load balancer
- Kubernetes eviction

---

### 3. Excessive Health Check Frequency
**Status**: ⚠️ High Priority

**Observed Behavior**:
```
INFO:     10.0.3.156:37278 - "GET /ready HTTP/1.1" 200 OK
INFO:     10.0.3.156:55226 - "GET /ready HTTP/1.1" 200 OK
INFO:     10.0.3.156:55236 - "GET /ready HTTP/1.1" 200 OK
... (repeats every ~5 seconds)
```

**Issues**:
- Health checks appear every ~5 seconds
- Both `/ready` and `/health` are being called
- Too frequent for a stable pod
- Clutters logs making debugging harder

**Questions**:
- Who is calling these? (Kubernetes probes or load balancer?)
- Can we reduce frequency?
- Do we need both `/ready` and `/health` or just one?

**Current Probe Configuration** (from terraform):
```hcl
readiness_probe {
  initial_delay_seconds = 30
  period_seconds        = 10   # Every 10 seconds
  timeout_seconds       = 5
  failure_threshold     = 30
}

liveness_probe {
  initial_delay_seconds = 60
  period_seconds        = 30   # Every 30 seconds
  timeout_seconds       = 10
  failure_threshold     = 10
}
```

---

### 4. Missing Timestamps on Access Logs
**Status**: ⚠️ Medium Priority

**Observed Behavior**:
Some log entries have timestamps:
```
2025-11-24 20:01:51,633 - service_chat.main - INFO - Model loaded successfully
```

But Uvicorn access logs don't:
```
INFO:     10.0.3.156:55226 - "GET /ready HTTP/1.1" 200 OK
```

**Impact**:
- Hard to correlate events
- Can't determine exact timing of requests
- Difficult to debug timeout issues

**Root Cause**:
Uvicorn's default access logging format doesn't include timestamps

---

### 5. Max Tokens Too Low (256)
**Status**: 🟡 Low Priority (Performance)

**Current Setting**: `GGUF_MAX_TOKENS=256` (~192 words)

**Recommendation**: Increase to 512-1024 for more complete medical responses

**Trade-off**:
- Higher = More complete answers
- Higher = Longer inference time

---

## Root Cause Analysis

### Primary Hypothesis: Pod is Being Killed During Inference

**Evidence**:
1. ✅ Inference starts (`llm_inference_start`)
2. ❌ Inference never completes (no `llm_inference_end` log)
3. ✅ Logs show pod restart after failed request
4. ✅ Frontend receives `ERR_EMPTY_RESPONSE` (connection closed)

**Possible Culprits**:

#### A. Liveness Probe Timeout
Current config:
```hcl
liveness_probe {
  initial_delay_seconds = 60    # Only 60s grace period
  period_seconds        = 30    # Check every 30s
  timeout_seconds       = 10    # Must respond in 10s
  failure_threshold     = 10    # 10 failures = 300s max
}
```

**Math**: 60s initial + (10 failures × 30s period) = 360s (6 minutes) max before restart

If inference takes 3-5 minutes and blocks the event loop, liveness probes may fail and kill the pod.

#### B. Out of Memory (OOM)
Current limits:
```hcl
memory_request = "4Gi"
memory_limit   = "8Gi"
```

GGUF model needs:
- ~1GB for model file
- ~2GB for inference context
- Python overhead

Should be fine, but worth checking actual memory usage.

#### C. Load Balancer Timeout
AWS ELB default idle timeout: **60 seconds**

If request takes >60s with no data sent, ELB may close connection.

#### D. Inference Blocking Event Loop
If llama.cpp is blocking the Python event loop during inference:
- Health checks can't respond
- Probes fail
- Pod gets killed

---

## Investigation Plan

### Step 1: Check Pod Events and Restarts
```bash
kubectl describe pod -l app=chat-api -n carepath-demo
kubectl get events -n carepath-demo --sort-by='.lastTimestamp' | grep chat-api
```

Look for:
- OOMKilled events
- Liveness probe failures
- Evictions

---

### Step 2: Check Actual Resource Usage
```bash
kubectl top pod -l app=chat-api -n carepath-demo
```

Monitor during inference to see if memory spikes.

---

### Step 3: Test Direct Pod Connection (Bypass Load Balancer)
```bash
kubectl port-forward -n carepath-demo svc/chat-api-service 8002:80
curl -X POST http://localhost:8002/triage \
  -H "Content-Type: application/json" \
  -d '{"patient_mrn": "P000123", "query": "test"}'
```

This bypasses ELB timeout to isolate the issue.

---

### Step 4: Check Load Balancer Timeout Settings
```bash
aws elbv2 describe-load-balancers \
  --profile AdministratorAccess-513291423126 \
  --region us-east-2 | grep -A5 a69d9c05b2057
```

Check `IdleTimeout` attribute.

---

### Step 5: Add Inference Timeout Logging
Add timing around inference call to see if it's actually hanging or just slow.

---

## Proposed Fixes

### Fix 1: Increase Liveness Probe Tolerance (Quick)
```hcl
liveness_probe {
  initial_delay_seconds = 180   # Increase from 60 to 180
  period_seconds        = 30
  timeout_seconds       = 10
  failure_threshold     = 20    # Increase from 10 to 20 (10 minutes grace)
}
```

**Rationale**: Give inference more time to complete without pod being killed.

---

### Fix 2: Increase Load Balancer Idle Timeout (Quick)
Add to Kubernetes service annotations:
```hcl
metadata {
  annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout" = "600"
  }
}
```

**Rationale**: Allow long-running requests (up to 10 minutes).

---

### Fix 3: Run Inference in Background Thread (Medium Effort)
Current inference blocks the event loop. Move to background thread:
```python
import asyncio
from concurrent.futures import ThreadPoolExecutor

executor = ThreadPoolExecutor(max_workers=1)

async def generate_response_async(...):
    loop = asyncio.get_event_loop()
    response = await loop.run_in_executor(
        executor,
        _model_cache,
        prompt
    )
    return response
```

**Rationale**: Keep event loop responsive for health checks during inference.

---

### Fix 4: Reduce Health Check Frequency (Low Effort)
```hcl
readiness_probe {
  period_seconds = 30   # Reduce from 10 to 30
}

liveness_probe {
  period_seconds = 60   # Reduce from 30 to 60
}
```

**Rationale**: Less log spam, less overhead.

---

### Fix 5: Add Timestamps to Uvicorn Logs (Low Effort)
Update uvicorn command in Dockerfile or add logging config:
```python
# service_chat/main.py
import logging

logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    force=True  # Override uvicorn's default
)
```

---

### Fix 6: Add Request Streaming or Progress Updates (Medium Effort)
Send periodic "thinking..." updates during inference to keep connection alive:
```python
async def triage_streaming(...):
    async for chunk in generate_with_progress():
        yield f"data: {json.dumps({'status': 'thinking'})}\n\n"
```

---

## Implementation Plan (2024-11-24)

**Confirmed Root Cause**: Inference blocks Python event loop → Health probes timeout → Pod killed after 30s

### Fixes to Apply

- [x] **Fix 1: Run Inference in Background Thread** (Best fix - keeps event loop responsive)
  - [x] Update `service_chat/services/llm_client.py` to use ThreadPoolExecutor
  - [x] Test locally first to verify it works
  - [x] Build and push new Docker image
  - [x] Deploy to cloud

- [x] **Fix 2: Increase Liveness Probe Tolerance** (Allow more time for slow operations)
  - [x] Update `infra/terraform/modules/app/main.tf`:
    - [x] `period_seconds = 120` (check every 2 minutes)
    - [x] `timeout_seconds = 180` (3 minute timeout per check)
    - [x] `failure_threshold = 20` (20 failures before restart)
    - [x] Math: 120s × 20 = 2400s = 40 minutes grace period
  - [x] Run `terraform plan` and `terraform apply`

- [x] **Fix 3: Reduce Readiness Probe Frequency** (Less log spam)
  - [x] Update `infra/terraform/modules/app/main.tf`:
    - [x] `period_seconds = 120` (check every 2 minutes instead of 5s)
  - [x] Apply with terraform

- [x] **Fix 4: Add Uvicorn Timestamp Logging** (Better debugging)
  - [x] Add logging configuration to uvicorn
  - [x] Test locally
  - [x] Include in Docker image rebuild

- [x] **Fix 5: Verify Load Balancer Timeout** (Prevent ELB from closing connection)
  - [x] Check current terraform configuration for LB timeout annotation
  - [x] Verify it's set to 600s (10 minutes)
  - [x] Apply if needed

### Testing Plan

- [x] Test Fix 1 locally with `make run-chat`
- [x] Verify background thread doesn't break inference
- [x] Deploy all fixes to cloud
- [ ] Test `/triage` endpoint via frontend (ready for user testing)
- [ ] Monitor pod logs during inference
- [ ] Verify pod doesn't restart
- [ ] Confirm response completes successfully

---

## Questions to Answer

1. **Did the pod actually restart?**
   - Check `kubectl get pods -l app=chat-api -n carepath-demo -o wide` for restart count
   - Check pod age vs. request time

2. **What killed it?**
   - OOM? (check events)
   - Liveness probe? (check events)
   - Node eviction? (check node events)

3. **How long did inference actually take?**
   - Add timing logs before/after `_model_cache()` call

4. **Is the model too slow on CPU?**
   - 3-5 minutes for 256 tokens is very slow
   - Locally takes 2 minutes
   - May need GPU or better CPU

---

## Notes

- Local inference: ~2 minutes first request, 5-30s subsequent
- Cloud inference: Never completes, times out after 3-5 minutes
- GGUF model: Qwen2.5-1.5B-Instruct (Q4_K_M quantization)
- Node: r5.large (2 vCPU, 16GB RAM)
- May need to profile llama.cpp performance on this CPU

---

## Session Timeline

### First Deployment (Session 2 Start)
1. **20:00:47** - User submitted query via frontend
2. **20:00:47** - Request received, inference started
3. **~20:03-20:05** - Request timed out (3-5 minutes)
4. **20:01:50** - Logs show pod restart (exact timing unclear due to missing timestamps)
5. **After restart** - Pod came back up, loaded model successfully

### After Fixes Applied (Thread Pool + Probe Tuning)
1. **21:03:23** - First request received, inference started
2. **21:13:23** - Second request received (10 min later, possibly auto-retry)
3. **21:15+** - Still no completion after 15+ minutes (7.5x slower than local)
4. **Issue**: Inference hanging or extremely slow on cloud CPU

---

## NEW ISSUES - Session 3 (2024-11-24)

### Issue 6: Inference Extremely Slow on Cloud (15+ min vs 2 min local)
**Status**: 🔴 Critical

**Observed Behavior**:
- Local inference: ~2 minutes for first request
- Cloud inference: 15+ minutes and still running
- No error, no completion - just hanging in `model()` call

**Timeline**:
```
21:03:23 - "Starting llama.cpp inference..."  ✅
21:03:23 - "Generating response with llama.cpp..."  ✅
(15+ minutes of silence)
❌ No "Response generated" log
```

**Evidence**:
- Both requests show `llm_inference_start` but no `llm_inference_end`
- Second request doesn't even show "Using cached llama.cpp model" log
- ThreadPoolExecutor is blocking - second request queued waiting for first

**Possible Causes**:
1. **CPU Performance**: r5.large (2 vCPU, older Xeon) much slower than local CPU
2. **CPU Instruction Sets**: Missing AVX2/AVX512, llama.cpp falling back to slow code path
3. **Resource Throttling**: Kubernetes CPU throttling (1 CPU request, 2 CPU limit)
4. **Deadlock**: Thread hanging in llama.cpp (less likely, as health checks still work)
5. **Memory Swapping**: Model too large for available RAM, swapping to disk

**Node Info**: r5.large = 2 vCPU, 16GB RAM, Intel Xeon Platinum 8000 series

---

### Issue 7: Uvicorn Timestamps Still Missing (Despite Fix Attempt)
**Status**: 🟡 Medium Priority

**Observed**:
```
INFO:     10.0.3.156:47844 - "GET /health HTTP/1.1" 200 OK
```

**Expected**:
```
2025-11-24 21:03:23 - uvicorn.access - INFO:  10.0.3.156:47844 - "GET /health HTTP/1.1" 200 OK
```

**Root Cause**: uvicorn.access logger has its own handler set at runtime by uvicorn, which overrides logging.basicConfig's force=True

**Fix Applied**: Explicitly clear handlers and add our own formatter to uvicorn.access logger

---

### Issue 8: No Visibility Into Inference Progress
**Status**: 🟡 Medium Priority

**Problem**: When inference takes 15+ minutes, we have no idea if it's making progress or hung

**Previous Logging**:
```python
logger.info("Generating response with llama.cpp GGUF model...")
output = model(...)  # Black box - no visibility
logger.info("Response generated in X.Xs")
```

**Fix Applied**: Added granular timing logs:
- Model load time
- Prompt build time and length
- Thread name for visibility
- Before/after model() call with explicit warnings

**New Logging**:
```python
logger.info(f"[{thread_name}] Loading model (cached)...")
logger.info(f"[{thread_name}] Model loaded in X.Xs")
logger.info(f"[{thread_name}] Prompt built in X.Xs (length=N chars)")
logger.info(f"[{thread_name}] Starting llama.cpp inference...")
logger.info(f"[{thread_name}] Calling model() - this may take several minutes on CPU...")
# model() call
logger.info(f"[{thread_name}] model() call completed in X.Xs")
logger.info(f"[{thread_name}] Response generated in X.Xs total")
```

---

## Next Steps for Investigation

### Immediate (To Deploy Now)
- [x] Add detailed timing logs to inference pipeline
- [x] Fix uvicorn timestamp logging
- [x] Test locally to verify logging works
- [x] Build and push new Docker image
- [x] Deploy to cloud
- [ ] Monitor logs during next inference attempt (ready for user to test)

### If Performance Still Poor
1. **Check CPU specs on node**:
   ```bash
   kubectl get node -o wide
   aws ec2 describe-instances --instance-ids <node-id> --profile <profile>
   ```

2. **Check actual CPU usage during inference**:
   - Install metrics-server if not available
   - Use CloudWatch for EC2 instance metrics

3. **Test llama.cpp CPU optimizations**:
   - Check if BLAS/OpenBLAS is being used
   - Verify AVX2 support: `lscpu | grep avx2`
   - Try different n_threads settings

4. **Consider alternatives**:
   - Upgrade to compute-optimized instance (c5.xlarge, c6i.xlarge)
   - Use GPU instance (g4dn.xlarge with CUDA)
   - Switch to managed LLM API (OpenAI, Anthropic, etc.)
   - Reduce max_tokens further (256 → 128)
