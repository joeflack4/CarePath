# Model Management

This document explains how CarePath AI manages Large Language Models (LLMs), including downloading, deploying, switching 
between models, and rollback procedures.

---

## Overview

CarePath AI's chat service (`service_chat`) supports multiple LLM modes:

- **mock**: Returns hardcoded responses (for testing, MVP)
- **qwen** / **Qwen3-4B-Thinking-2507**: Uses Qwen3-4B-Thinking-2507 model from Hugging Face

The active mode is controlled via the `LLM_MODE` environment variable.

---

## Architecture

### Model Manager (`service_chat/services/model_manager.py`)

Handles automatic download and caching of models from Hugging Face.

**Key Functions**:
- `download_model_if_needed()`: Downloads model if not already cached
- `load_qwen_model()`: Loads model and tokenizer into memory
- `get_model_cache_dir()`: Returns path to model cache directory

**Model Caching**:
- Default cache directory: `/app/models` (configurable via `MODEL_CACHE_DIR` env var)
- Models are cached to avoid re-downloading on every container restart
- Cache is per-pod ephemeral storage by default (cleared when pod is deleted)
- For persistence, mount a shared PersistentVolume (see [Persistent Model Cache](#persistent-model-cache))

### LLM Client (`service_chat/services/llm_client.py`)

Provides unified interface for generating responses across different LLM modes.

**Key Functions**:
- `generate_response_mock()`: Returns mock response
- `generate_response_qwen()`: Uses Qwen model for inference
- `generate_response()`: Dispatcher that routes to appropriate implementation based on mode

**Model Caching**:
- Model and tokenizer are loaded once per container and cached in memory (`_model_cache`)
- Subsequent requests reuse the cached model (no re-loading)
- Model is only loaded when first request with `LLM_MODE=qwen` is received

---

## Local Development

### Prerequisites

1. Python 3.11+
2. Virtual environment activated (see `CLAUDE.md`)
3. At least 10GB free disk space for model download
4. Optional: Hugging Face account and token (if model requires authentication)

### Installing Dependencies

```bash
# Install base chat service dependencies
make install-chat

# Install LLM-specific dependencies (torch, transformers, huggingface-hub)
make install-chat-llm
```

### Downloading Models

**Option 1: Using Makefile**
```bash
# Downloads Qwen3-4B-Thinking-2507 to ./models/ directory
make download-llm-model
```

**Option 2: Using Python directly**
```bash
python -c "from service_chat.services.model_manager import download_model_if_needed; download_model_if_needed()"
```

**Option 3: With Hugging Face token** (if model requires authentication)
```bash
export HUGGINGFACE_TOKEN="hf_your_token_here"
make download-llm-model
```

### Running with Real LLM Locally

1. Create `.env` file (if not exists):
   ```bash
   cp .env.example .env
   ```

2. Update `.env`:
   ```bash
   LLM_MODE=Qwen3-4B-Thinking-2507
   MODEL_CACHE_DIR=./models  # Optional: use local directory
   ```

3. Start the service:
   ```bash
   make run-chat
   ```

4. Test the endpoint:
   ```bash
   curl -X POST http://localhost:8002/triage \
     -H "Content-Type: application/json" \
     -d '{
       "patient_mrn": "MRN-001",
       "query": "What are my current medications?"
     }'
   ```

---

## Deployment

### Model Deployment Strategies

There are two approaches to deploying models to Kubernetes:

#### Strategy 1: Download on First Startup (Recommended for MVP)

**How it works**:
- Docker image does NOT include the model
- Model is downloaded when first pod starts up
- Each pod downloads model independently to its ephemeral storage

**Pros**:
- Smaller Docker image (~500MB vs ~8GB)
- Faster image builds and pushes
- Less storage required in ECR

**Cons**:
- First pod startup takes 5-15 minutes (model download time)
- Each pod downloads the model independently (network bandwidth)
- Model is lost when pod is deleted (re-download needed)

**Build Command**:
```bash
# Default - model NOT included
docker build -t carepath-chat-api:latest -f service_chat/Dockerfile service_chat/
```

#### Strategy 2: Embed Model in Image

**How it works**:
- Model is downloaded during Docker image build
- Model is embedded in the Docker image
- Pods start immediately with model already available

**Pros**:
- Fast pod startup (~30 seconds)
- No download time or network usage during startup
- Consistent across all pods

**Cons**:
- Large Docker image (~8GB)
- Slow image builds (10-20 minutes for first build)
- Slow image pushes to ECR
- Higher ECR storage costs

**Build Command**:
```bash
docker build \
  --build-arg DOWNLOAD_MODEL=true \
  --build-arg HUGGINGFACE_TOKEN="$HUGGINGFACE_TOKEN" \
  -t carepath-chat-api:latest \
  -f service_chat/Dockerfile \
  service_chat/
```

### Deployment Workflow

See `notes/ai-service-upgrade.md` for detailed step-by-step deployment instructions.

**Quick Steps**:

1. Build and push image:
   ```bash
   make docker-build-chat
   make docker-push-chat
   ```

2. Update Terraform config:
   ```hcl
   # infra/terraform/envs/demo/terraform.tfvars
   chat_api_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/carepath-chat-api:v2.0"
   ```

3. Update ConfigMap to enable Qwen mode:
   ```hcl
   # infra/terraform/modules/app/main.tf
   env {
     name  = "LLM_MODE"
     value = "Qwen3-4B-Thinking-2507"
   }
   ```

4. Apply changes:
   ```bash
   make tf-apply
   ```

5. Monitor rollout:
   ```bash
   kubectl rollout status deployment/chat-api -n carepath-demo
   ```

---

## Switching LLM Modes

You can switch between mock and real LLM modes without rebuilding the image.

### Switch to Mock Mode

```bash
# Update environment variable in Kubernetes
kubectl set env deployment/chat-api LLM_MODE=mock -n carepath-demo

# This triggers a rolling restart of pods
```

### Switch to Qwen Mode

```bash
kubectl set env deployment/chat-api LLM_MODE=Qwen3-4B-Thinking-2507 -n carepath-demo
```

### Switch via Terraform (Preferred)

Update `infra/terraform/modules/app/main.tf`:
```hcl
env {
  name  = "LLM_MODE"
  value = "Qwen3-4B-Thinking-2507"  # or "mock"
}
```

Then apply:
```bash
make tf-apply
```

---

## Rollback Procedures

### Rollback to Previous Deployment

If the new model deployment causes issues:

```bash
# Quick rollback to previous version
kubectl rollout undo deployment/chat-api -n carepath-demo

# Check rollback status
kubectl rollout status deployment/chat-api -n carepath-demo
```

### Rollback to Mock Mode

```bash
# Switch LLM_MODE back to mock (keeps current image)
kubectl set env deployment/chat-api LLM_MODE=mock -n carepath-demo
```

### Rollback via Terraform

1. Revert changes in `terraform.tfvars` (old image tag)
2. Revert changes in `app/main.tf` (LLM_MODE=mock)
3. Apply:
   ```bash
   make tf-apply
   ```

---

## Persistent Model Cache

To avoid re-downloading models on every pod restart, use a PersistentVolume.

### Create PersistentVolumeClaim

Add to `infra/terraform/modules/app/main.tf`:

```hcl
resource "kubernetes_persistent_volume_claim" "model_cache" {
  metadata {
    name      = "model-cache"
    namespace = kubernetes_namespace.app.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteMany"]  # Shared across pods
    resources {
      requests = {
        storage = "20Gi"  # Enough for multiple models
      }
    }
    storage_class_name = "efs-sc"  # Use EFS for shared access
  }
}
```

### Mount Volume in Deployment

Update deployment spec:

```hcl
resource "kubernetes_deployment" "chat_api" {
  spec {
    template {
      spec {
        # Add volume
        volume {
          name = "model-cache"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.model_cache.metadata[0].name
          }
        }

        container {
          # Mount volume
          volume_mount {
            name       = "model-cache"
            mount_path = "/app/models"
          }

          env {
            name  = "MODEL_CACHE_DIR"
            value = "/app/models"
          }
        }
      }
    }
  }
}
```

### Setup EFS (for ReadWriteMany support)

EKS doesn't support ReadWriteMany by default. You need EFS:

1. Install EFS CSI driver:
   ```bash
   kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.5"
   ```

2. Create EFS file system via Terraform (add to `infra/terraform/modules/efs/`)

3. Create StorageClass:
   ```yaml
   kind: StorageClass
   apiVersion: storage.k8s.io/v1
   metadata:
     name: efs-sc
   provisioner: efs.csi.aws.com
   ```

**Note**: EFS adds complexity and cost. For MVP, ephemeral storage (no persistence) is acceptable.

---

## Model Configuration

### Qwen3-4B-Thinking-2507 Parameters

Located in `service_chat/services/llm_client.py`:

```python
outputs = model.generate(
    inputs.input_ids,
    max_new_tokens=512,       # Maximum response length
    temperature=0.7,          # Randomness (0.0 = deterministic, 1.0 = creative)
    top_p=0.9,               # Nucleus sampling
    do_sample=True,          # Enable sampling (vs greedy)
    pad_token_id=tokenizer.eos_token_id
)
```

### Tuning Parameters

- **max_new_tokens**: Increase for longer responses (512 → 1024), but increases latency
- **temperature**: Lower (0.3) for factual responses, higher (0.9) for creative responses
- **top_p**: Nucleus sampling threshold (0.9 is standard)

Changes require code modification and redeployment.

---

## Performance Considerations

### CPU Inference (Current)

- **Instance Type**: t3.medium or t3.large
- **Expected Latency**: 5-15 seconds per request
- **Concurrency**: Limited (1-2 requests per pod simultaneously)
- **Cost**: Low (~$30-60/month for node group)

### GPU Inference (Future)

For better performance, consider GPU instances:

- **Instance Type**: g4dn.xlarge (1 GPU, 4 vCPUs, 16GB RAM)
- **Expected Latency**: 1-3 seconds per request
- **Concurrency**: Higher (5-10 requests per pod)
- **Cost**: Higher (~$300-500/month)

**Migration**: Update `node_instance_types` in Terraform to include GPU instances, update Dockerfile to use GPU-enabled PyTorch.

---

## Troubleshooting

### Model Download Fails

**Symptom**: Pod logs show "Failed to download model"

**Causes**:
1. No internet access from pods
2. Hugging Face rate limiting
3. Model requires authentication

**Solutions**:
```bash
# Check NAT gateway (pods need internet access)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl https://huggingface.co

# Add Hugging Face token as Secret
kubectl create secret generic huggingface-token \
  --from-literal=token=$HUGGINGFACE_TOKEN \
  -n carepath-demo

# Update deployment to use secret
env {
  name = "HUGGINGFACE_TOKEN"
  value_from {
    secret_key_ref {
      name = "huggingface-token"
      key  = "token"
    }
  }
}
```

### Out of Memory (OOM)

**Symptom**: Pods crash with OOMKilled status

**Cause**: Model requires more memory than pod limit

**Solutions**:
```bash
# Increase memory limits in deployment
resources {
  limits = {
    memory = "8Gi"  # Increase from 512Mi
  }
  requests = {
    memory = "4Gi"
  }
}

# Or upgrade node instance type
node_instance_types = ["t3.xlarge"]  # 16GB RAM
```

### Slow Responses

**Symptom**: Latency >30 seconds

**Causes**:
1. CPU inference is slow
2. Node CPU throttling
3. Too many concurrent requests

**Solutions**:
- Reduce `max_new_tokens` (512 → 256)
- Lower `temperature` for faster generation
- Increase pod CPU limits
- Add more replicas to distribute load
- Consider GPU instances

### Model Not Loading

**Symptom**: "Model not found" or "Unable to load model"

**Check**:
```bash
# SSH into pod
kubectl exec -it <pod-name> -n carepath-demo -- /bin/bash

# Check model directory
ls -lh /app/models/

# Check environment
env | grep MODEL
env | grep LLM_MODE

# Try manual download
python -c "from service_chat.services.model_manager import download_model_if_needed; download_model_if_needed()"
```

---

## Cost Implications

### Storage Costs

- **ECR Image Storage**: ~$0.10/GB/month
  - Mock mode image: ~0.5GB = $0.05/month
  - Qwen embedded image: ~8GB = $0.80/month

- **EFS (if using persistent cache)**: ~$0.30/GB/month
  - Model cache: ~10GB = $3/month

### Compute Costs

- **t3.medium** (2 vCPU, 4GB): ~$0.0416/hour = $30/month
- **t3.large** (2 vCPU, 8GB): ~$0.0832/hour = $60/month
- **g4dn.xlarge** (4 vCPU, 16GB, 1 GPU): ~$0.526/hour = $380/month

**Recommendation**: Start with t3.medium or t3.large for MVP, upgrade to GPU if latency becomes an issue.

---

## Future Enhancements

- **Model Versioning**: Support multiple model versions simultaneously
- **A/B Testing**: Route traffic to different models for comparison
- **Quantization**: Use 4-bit or 8-bit quantized models for faster inference
- **Model Serving**: Use Triton Inference Server or TorchServe for optimized serving
- **Multi-GPU**: Distribute model across multiple GPUs for very large models
- **Fine-tuning**: Fine-tune Qwen on healthcare-specific data

---

## References

- Qwen3-4B-Thinking-2507: https://huggingface.co/Qwen/Qwen3-4B-Thinking-2507
- Hugging Face Hub: https://huggingface.co/docs/hub/index
- Transformers Library: https://huggingface.co/docs/transformers/index
- PyTorch: https://pytorch.org/docs/stable/index.html
- Deployment Options: `notes/rollout-options.md`
- Upgrade Guide: `notes/ai-service-upgrade.md`
