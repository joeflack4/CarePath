# Deploy Fixes Report 1 - Session Summary
Note: when this document says 'Qwen3-4B-Thinking-2507', this is what was originally used at the time, but has since been replaced with default of: Qwen2.5-3B-Instruct

**Date**: 2024-11-24
**Issue**: Chat-api pod restarts during Qwen3-4B model loading (~90s blocking operation)

---

## What Was Done This Session

### 1. Documented Options in `deploy-fixes.md`
Added 5 solution options for the model loading problem:
- **Option 1**: Increase probe failure thresholds (implemented)
- **Option 2**: Add startup probe
- **Option 3**: Eager model loading on startup (recommended future improvement)
- **Option 4**: Background model loading with status endpoint
- **Option 5**: Accept 90s first request delay

### 2. Implemented Option 1: Increased Probe Thresholds
Modified `infra/terraform/modules/app/main.tf`:

```hcl
liveness_probe {
  initial_delay_seconds = 30   # Start checking quickly
  period_seconds        = 30   # Check every 30s
  timeout_seconds       = 10
  failure_threshold     = 15   # 15 × 30s = 7.5 min grace
}

readiness_probe {
  initial_delay_seconds = 10
  period_seconds        = 10   # Check every 10s
  timeout_seconds       = 5
  failure_threshold     = 60   # 60 × 10s = 10 min grace
}
```

### 3. Applied Terraform Changes
- Ran `terraform apply` successfully
- Resolved state lock issue with `terraform force-unlock`
- Resolved rolling deployment deadlock by manually deleting old pod

---

## Current Status

### What's Working
- EBS CSI driver installed and functioning
- PVC (15Gi) bound and working - model downloads once, cached on persistent storage
- Model downloads to PVC in ~50 seconds
- Pod starts and serves health checks immediately
- Terraform changes applied successfully

### What's Still Being Tested
A test `/triage` request was sent at **03:33:16** to trigger model loading. At that moment:
- Pod: `chat-api-85c7d6df4b-wns5g`
- Restart count: 1 (from a restart BEFORE Terraform finished)
- Settings verified: `failureThreshold: 15`

**The test should complete around 03:34:46** (~90s for model loading).

### Test Result: FAILED

**Pod restarted again!** Restart count went from 1 → 2.

Even with `failureThreshold=15` (7.5 min grace), the pod still restarts during model loading.

**Conclusion**: Option 1 (probe threshold tweaking) is NOT working reliably.

**Recommendation**: Move to **Option C (Eager Model Loading)** - it's a more robust solution that will actually fix the root cause rather than trying to work around it with probe settings.

---

## Background Processes Still Running

Several background bash processes were started during debugging:
- ID `242560`: Test /triage request with logs monitoring
- ID `a9bd86`: Longer test with 2-minute wait and pod status check
- Many older test processes from earlier attempts

To check results:
```bash
# Check if test completed
kubectl get pods -n carepath-demo -l app=chat-api

# Check restart count - should still be 1
kubectl describe pod -n carepath-demo -l app=chat-api | grep Restart

# Check model loading logs
kubectl logs -n carepath-demo -l app=chat-api --tail=50
```

---

## Options If Current Approach Fails

If the pod still restarts with `failureThreshold=15`, consider:

### Option A: More Aggressive Thresholds
```hcl
failure_threshold = 30  # 30 × 30s = 15 min grace
```

### Option B: Startup Probe (Better K8s Pattern)
Add a separate startup probe that only runs during container initialization:
```hcl
startup_probe {
  http_get {
    path = "/health"
    port = 8002
  }
  initial_delay_seconds = 10
  period_seconds        = 10
  failure_threshold     = 60  # 10 min for startup
}
```

### Option C: Eager Model Loading (Best UX, More Work)
Modify `service_chat/main.py` to load model during FastAPI startup:
1. Add `lifespan` context manager that calls `_load_model_cached()`
2. Add `/ready` endpoint that returns 503 until model is loaded
3. Update readiness probe to use `/ready` instead of `/health`

This way:
- Pod isn't "ready" until model is actually loaded
- First user request is fast (model already in RAM)
- No surprises for users

---

## Recommended Next Steps

1. **Check test results** - Did pod survive model loading?
   ```bash
   kubectl get pods -n carepath-demo -l app=chat-api
   ```

2. **If successful** (restart count = 1):
   - Send another /triage request to verify fast response
   - Document success, mark deployment complete

3. **If failed** (restart count > 1):
   - Consider Option C (eager model loading)
   - May save time vs. trial-and-error with probe settings
   - Implementation is straightforward (~30-60 min)

---

## Files Modified This Session

- `infra/terraform/modules/app/main.tf` - Probe settings
- `notes/deploy-fixes.md` - Added options documentation

## Files to Reference

- `notes/deploy-fixes.md` - Full options documentation
- `notes/issues/6-very-high/ai-service-upgrade.md` - Deployment checklist
- `infra/terraform/envs/demo/terraform.tfvars` - Current config
