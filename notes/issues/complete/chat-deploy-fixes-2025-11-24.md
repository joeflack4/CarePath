# Deploy Fixes - AI Service Upgrade Blockers
Note: when this document says 'Qwen3-4B-Thinking-2507', this is what was originally used at the time, but has since been replaced with default of: Qwen2.5-3B-Instruct

## Current Issue Summary

The chat-api pod with Qwen3-4B-Thinking-2507 LLM cannot schedule due to multiple issues discovered during debugging.

### Root Causes Identified

1. **EBS CSI Driver Missing (Critical)**
   - Only `efs.csi.aws.com` is installed, not `ebs.csi.aws.com`
   - PVC uses `storageClass: gp2` which requires EBS CSI driver
   - Error: "Waiting for a volume to be created either by the external provisioner 'ebs.csi.aws.com'"

2. **Earlier Pod Eviction Due to Ephemeral Storage**
   - Previous pod (without PVC) downloaded model to ephemeral storage (~3.2GB)
   - Node ran low on ephemeral storage (only 340MB available)
   - Pod was evicted with disk pressure

3. **Scheduler Reports "Insufficient cpu, Insufficient memory"**
   - Node allocatable: 1930m CPU, ~14.6Gi memory
   - Pod requests: 1000m CPU, 9Gi memory
   - Currently allocated: 450m CPU, 396Mi memory
   - Math should work but scheduler rejects - likely due to volume binding issues or scheduler state

---

## Solution Options

### Option A: Install EBS CSI Driver (Recommended & chosen - Proper Fix) ✅ COMPLETED
- [x] Create IAM role for EBS CSI driver with required permissions
- [x] Install EBS CSI driver addon via EKS
- [x] Verify PVC can provision EBS volume (15Gi gp2 EBS bound)
- [x] Confirm pod schedules successfully (chat-api-5cc8b4c685-rh8xq Running)
- [x] Model download initiated to PVC at /app/models

### Option B: Disable PVC, Use Larger Instance (Quick Fix)
Set `enable_model_cache_pvc = false` in terraform.tfvars
Upgrade to `r5.xlarge` (32GB RAM, more ephemeral storage) - it's possible this may already have been done
Let model download to ephemeral storage
Accept that model re-downloads on each pod restart

### Option C: Switch Storage Class to EFS
- Create EFS filesystem in AWS
- Configure EFS access points
- Change `storage_class_name` to use EFS
- More complex setup but supports ReadWriteMany

---

## Implementation Progress

### Option A Implementation (In Progress)

**Step 1: Create IAM Role for EBS CSI Driver**
```bash
# IAM policy ARN for EBS CSI
arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
```

**Step 2: Install EBS CSI Driver Addon**
```hcl
# Add to EKS module
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"
  # ... IAM role configuration
}
```

**Step 3: Verify Installation**
```bash
kubectl get csidrivers
# Should show: ebs.csi.aws.com
```

---

## Debugging Commands Used

```bash
# Check node resources and allocations
kubectl describe node <node-name>

# Check pod scheduling events
kubectl describe pod <pod-name> -n carepath-demo

# Check PVC status
kubectl get pvc -n carepath-demo
kubectl describe pvc chat-api-model-cache -n carepath-demo

# Check CSI drivers installed
kubectl get csidrivers

# Check recent events
kubectl get events -n carepath-demo --sort-by='.lastTimestamp'
```

---

## Session Notes

**Date**: 2024-11-23

- Discovered EBS CSI driver is not installed (only EFS driver present)
- PVC stuck in Pending state waiting for volume provisioner
- Previous attempts without PVC failed due to ephemeral storage exhaustion
- Completed Option A: Install EBS CSI Driver

**Date**: 2024-11-24

- EBS CSI driver successfully installed and working
- PVC bound (15Gi gp2 EBS volume)
- Model downloads to PVC cache in ~50s (one-time)
- Model loads from PVC cache on subsequent restarts
- **New Issue**: First request triggers ~90s model load into memory (3 shards × ~30s each)
- This can cause liveness probe failures and request timeouts

---

## UPDATE: Moving to GGUF Backend (2024-11-24)

After testing, we've switched from the Transformers backend to GGUF for better performance:
- **Old**: Qwen3-4B-Thinking-2507 via Transformers (~7 min first inference)
- **New**: Qwen2.5-1.5B-Instruct via llama-cpp-python GGUF (~2-3 min)

### What's Already Done
- [x] GGUF backend implemented locally in `service_chat/services/llm_client.py`
- [x] Model configured: Qwen/Qwen2.5-1.5B-Instruct-GGUF (Q4_K_M quantization)
- [x] LLM_MODE="gguf" tested and working locally
- [x] Inference timing tracking added (backend + frontend)
- [x] Eager model loading implemented for Transformers mode

### What Needs to Be Done for GGUF Cloud Deployment
- [x] Update `main.py` lifespan handler to trigger eager loading for `LLM_MODE="gguf"` ✅ 2024-11-24
- [x] Verify GGUF dependencies are in `requirements.txt` (llama-cpp-python) ✅ Already present
- [x] Build new Docker image with GGUF support ✅ Added g++ compiler to Dockerfile
- [x] Update Terraform tfvars to use `LLM_MODE=gguf` ✅ Updated to "gguf"
- [x] Update resource limits (GGUF may need less memory than Transformers) ✅ Reduced to 4Gi request, 8Gi limit
- [x] Push image to ECR and deploy ✅ Image pushed, pod deployed
- [x] Test pod startup and verify model loads eagerly ✅ Model loads in ~5s on startup
- [ ] Test /triage endpoint response time - **BLOCKED: Pod restarts during inference (see chat-deploy-fixes2.md)**

---

## Current Issue: Model Loading Time (CONTEXT - applies to old Transformers approach)

After fixing the storage issue, we now have a new problem:

### Problem Summary

When the pod starts, it's ready to serve health checks immediately. However, the first `/triage` request triggers model loading into RAM, which takes ~90 seconds on CPU (r5.large). During this time:

1. The request may timeout (curl default 60s, or client timeout)
2. Liveness probes may fail if `initial_delay_seconds` + request time exceeds threshold
3. Pod may be restarted, losing the loaded model and requiring another ~90s load

### Current Probe Settings (infra/terraform/modules/app/main.tf)

```hcl
liveness_probe {
  initial_delay_seconds = 60    # Too short for 90s model load
  period_seconds        = 30
  timeout_seconds       = 10
  failure_threshold     = 10    # 10 failures × 30s = 5 minutes grace period
}

readiness_probe {
  initial_delay_seconds = 30
  period_seconds        = 10
  timeout_seconds       = 5
  failure_threshold     = 30    # 30 failures × 10s = 5 minutes grace period
}
```

### Why This Happens

Current architecture in `service_chat/services/llm_client.py`:
- Model is loaded **lazily** on first `/triage` request
- `_load_model_cached()` is called inside `generate_response_qwen()`
- Health endpoint (`/health`) returns immediately without loading model
- So pod appears "Ready" but first real request blocks for ~90s

---

## Solution Options for Model Loading Issue

### Option 1: Increase Liveness Probe Timeout (Quick Fix) ⭐ RECOMMENDED

**Effort**: ~5 minutes (Terraform change only)
**Risk**: Low
**Downside**: First request still takes ~90s

Changes to `infra/terraform/modules/app/main.tf`:
```hcl
liveness_probe {
  initial_delay_seconds = 180   # Increase from 60 to 180
  period_seconds        = 30
  timeout_seconds       = 10
  failure_threshold     = 10
}
```

**Pros**:
- Simplest change, no code modifications
- Pod won't be killed during first model load
- Works with current architecture

**Cons**:
- First user request still waits ~90s
- If pod is unhealthy, takes longer to detect

---

### Option 2: Startup Probe (Better K8s Pattern)

**Effort**: ~10 minutes (Terraform change only)
**Risk**: Low
**Downside**: Still lazy loading, first request slow

Add a startup probe that gives more time for initial startup:
```hcl
startup_probe {
  http_get {
    path = "/health"
    port = 8002
  }
  initial_delay_seconds = 10
  period_seconds        = 10
  timeout_seconds       = 5
  failure_threshold     = 30    # 30 × 10s = 5 minutes for startup
}

liveness_probe {
  # Keep existing settings - only runs after startup probe succeeds
  initial_delay_seconds = 10    # Can be shorter now
  period_seconds        = 30
  timeout_seconds       = 10
  failure_threshold     = 3
}
```

**Pros**:
- Better K8s pattern for slow-starting containers
- Separates startup concerns from runtime health
- Liveness probe can be more aggressive after startup

**Cons**:
- First request still blocks for ~90s
- Pod appears ready before model is actually loaded

---

### Option 3: Eager Model Loading on Startup (Better UX, Medium Effort)

**Effort**: ~30-60 minutes (code + Docker + deploy)
**Risk**: Medium (code changes required)
**Downside**: Slower pod startup (but better UX once ready)

Modify `service_chat/main.py` to load model during FastAPI startup:

```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Load model at startup
    if settings.LLM_MODE in ("qwen", "Qwen3-4B-Thinking-2507"):
        logger.info("Pre-loading LLM model at startup...")
        from service_chat.services.llm_client import _load_model_cached
        _load_model_cached()
        logger.info("LLM model loaded, ready for requests")
    yield

app = FastAPI(
    title="CarePath Chat API",
    lifespan=lifespan,
    ...
)
```

Then update readiness probe to use a smarter endpoint:
```python
@router.get("/health")
async def health():
    # Basic health check
    return {"status": "ok", ...}

@router.get("/ready")
async def ready():
    # Only return ready if model is loaded (for LLM mode)
    if settings.LLM_MODE in ("qwen", "Qwen3-4B-Thinking-2507"):
        from service_chat.services.llm_client import _model_cache
        if _model_cache is None:
            raise HTTPException(status_code=503, detail="Model not loaded")
    return {"status": "ready"}
```

Update Terraform to use `/ready` for readiness probe.

**Pros**:
- First user request is fast (~seconds, not 90s)
- Pod doesn't receive traffic until model is actually loaded
- Better user experience

**Cons**:
- Requires code changes + Docker rebuild + redeploy
- Pod takes ~90s to become ready (but this is expected)
- More complex than pure infra change

---

### Option 4: Background Model Loading with Status Endpoint (Most Robust)

**Effort**: ~1-2 hours (more code changes)
**Risk**: Medium
**Downside**: More complex, requires careful implementation

Similar to Option 3 but uses background thread:
- Start model loading in background thread at startup
- Expose `/health/model` endpoint showing load progress
- Return 503 from `/triage` if model not ready
- Log progress during loading

**Pros**:
- App starts quickly, model loads in background
- Can show loading progress to users
- Most production-ready approach

**Cons**:
- More complex implementation
- Need to handle race conditions
- May be overkill for demo environment

---

### Option 5: Accept 90s First Request (Do Nothing)

**Effort**: 0
**Risk**: None
**Downside**: Poor UX on first request after deployment/restart

Current behavior without any changes:
- First request blocks for ~90s
- May timeout depending on client
- Subsequent requests are fast (~5-10s for inference)

**Pros**:
- No changes required
- Model only loads when actually needed

**Cons**:
- First user sees 90s delay or timeout
- Confusing user experience
- May appear broken

---

## Recommendation

For getting up and running quickly:

**Recommended: Option 1 (Increase Probe Timeout)**

This is the fastest fix. Change `initial_delay_seconds` from 60 to 180 in the liveness probe. This gives the pod time to load the model on first request without being killed.

**Future improvement: Option 3 (Eager Loading on Startup)**

When you have time, implement eager model loading. This provides better UX because:
1. Pod isn't "ready" until model is loaded
2. First user request is fast
3. Load balancer won't route traffic to unready pods

The implementation is straightforward:
1. Add `lifespan` handler to `main.py` that calls `_load_model_cached()`
2. Optionally add `/ready` endpoint for readiness probe
3. Rebuild Docker image and redeploy

---

## Implementation Checklist

### Option 1: Increase Probe Timeout
- [ ] Update `infra/terraform/modules/app/main.tf`:
  - [ ] Change `initial_delay_seconds = 60` to `initial_delay_seconds = 180`
- [ ] Run `terraform plan` and `terraform apply`
- [ ] Verify pod doesn't restart during model load

### Option 3: Eager Model Loading ✅ COMPLETED 2024-11-24
- [x] Update `service_chat/main.py`:
  - [x] Add `lifespan` context manager
  - [x] Call `_load_model_cached()` during startup (for Transformers mode)
- [x] Extend eager loading to support GGUF mode (LLM_MODE="gguf") ✅ 2024-11-24
- [x] `/ready` endpoint already exists in `service_chat/routers/health.py` ✅ Already implemented
- [x] Terraform readiness probe already uses `/ready` ✅ Already configured
- [x] Rebuild Docker image with GGUF support (`make docker-build-chat`) ✅ 2024-11-24
- [x] Push to ECR (`make docker-push-chat`) ✅ 2024-11-24
- [x] Apply Terraform changes ✅ 2024-11-24

**Note**: Eager loading works, but new issue discovered - inference blocks event loop causing probes to fail (see chat-deploy-fixes2.md)
