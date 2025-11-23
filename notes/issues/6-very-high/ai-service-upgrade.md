# AI Service Upgrade - Qwen3-4B-Thinking-2507 Deployment

This document outlines the tasks required to deploy the chat-api service with the new Qwen3-4B-Thinking-2507 LLM model.

**Deployment Strategy**: Rolling Update (see `notes/rollout-options.md` for alternatives)

---

## Pre-Deployment Checklist

- [x] Verify model code is implemented and tested locally
  - [x] `service_chat/services/model_manager.py` exists
  - [x] `service_chat/services/llm_client.py` has `generate_response_qwen()` implemented
  - [x] Dependencies added to `requirements.txt` (torch, transformers, huggingface-hub, accelerate)

- [x] Test model locally (optional but recommended)
  - [x] Run `make install-chat-llm` to install LLM dependencies
  - [x] Run `make download-llm-model` to download model locally
  - [x] Set `LLM_MODE=Qwen3-4B-Thinking-2507` in `.env`
  - [x] Set `MODEL_CACHE_DIR=./models` in `.env`
  - [x] Run `make run-chat` and test `/triage` endpoint
  - [x] Verify response quality and latency (~7 min on CPU for first request)

- [ ] Review infrastructure requirements
  - [ ] Check EKS node instance size (CPU/memory requirements for Qwen3-4B)
  - [ ] Consider if current `t3.medium` nodes have sufficient resources
  - [ ] May need to upgrade to `t3.large` or `t3.xlarge` for CPU-based inference

---

## Build Phase

- [ ] Build Docker image with model embedded
  
  **Option A**: Build image with model pre-downloaded (larger image, faster startup) <-------
  ```bash
  cd service_chat
  docker build \
    --build-arg DOWNLOAD_MODEL=true \
    --build-arg HUGGINGFACE_TOKEN="$HUGGINGFACE_TOKEN" \
    -t carepath-chat-api:v2.0 \
    -f Dockerfile .
  ```

  **Option B**: Build image without model (smaller image, downloads on first startup)
  ```bash
  cd service_chat
  docker build -t carepath-chat-api:v2.0 -f Dockerfile .
  ```

- [ ] Test Docker image locally
  ```bash
  # Run container
  docker run -p 8002:8002 \
    -e LLM_MODE=Qwen3-4B-Thinking-2507 \
    -e DB_API_BASE_URL=http://host.docker.internal:8001 \
    carepath-chat-api:v2.0

  # Test endpoint
  curl http://localhost:8002/health
  ```

We're going with option 'a' for now

---

## Push Phase

- [ ] Authenticate with AWS ECR
  ```bash
  make ecr-login
  ```

- [ ] Tag and push image to ECR
  ```bash
  # Get ECR URL from Terraform output
  ECR_URL=$(cd infra/terraform/envs/demo && terraform output -raw chat_api_repo_url)

  # Tag image
  docker tag carepath-chat-api:v2.0 $ECR_URL:v2.0
  docker tag carepath-chat-api:v2.0 $ECR_URL:latest

  # Push both tags
  docker push $ECR_URL:v2.0
  docker push $ECR_URL:latest
  ```

---

## Infrastructure Update Phase

- [ ] Update Terraform configuration

  Edit `infra/terraform/envs/demo/terraform.tfvars`:
  ```hcl
  # Update chat-api image to v2.0
  chat_api_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/carepath-chat-api:v2.0"
  ```

- [ ] (Optional) Update node group instance type if needed

  Edit `infra/terraform/envs/demo/main.tf`:
  ```hcl
  module "eks" {
    # ...
    node_instance_types = ["t3.large"]  # Upgrade from t3.medium if needed
  }
  ```

- [ ] (Optional) Add model cache volume configuration

  Edit `infra/terraform/modules/app/main.tf` to add persistent volume for model cache:
  ```hcl
  # This is optional - model can download to pod ephemeral storage
  # Add PVC for model cache if you want persistence across pod restarts
  ```

- [ ] Update Kubernetes ConfigMap/Secret for LLM_MODE

  The app module should update the chat-api deployment env vars:
  ```hcl
  env {
    name  = "LLM_MODE"
    value = "Qwen3-4B-Thinking-2507"
  }
  ```

---

## Deployment Phase

- [ ] Plan Terraform changes
  ```bash
  make tf-plan
  ```

- [ ] Review the plan
  - [ ] Verify only chat-api deployment is changing
  - [ ] Check image URL is correct
  - [ ] Confirm environment variables are set

- [ ] Apply Terraform changes (triggers rolling update)
  ```bash
  make tf-apply
  ```

  Or deploy only chat service:
  ```bash
  make deploy-chat
  ```

- [ ] Monitor the rollout
  ```bash
  # Watch pod status
  kubectl get pods -n carepath-demo -w

  # Check rollout status
  kubectl rollout status deployment/chat-api -n carepath-demo

  # View events
  kubectl get events -n carepath-demo --sort-by='.lastTimestamp'
  ```

---

## Post-Deployment Validation

- [ ] Verify pods are running
  ```bash
  kubectl get pods -n carepath-demo -l app=chat-api
  ```

- [ ] Check pod logs for errors
  ```bash
  # Get pod name
  POD=$(kubectl get pods -n carepath-demo -l app=chat-api -o jsonpath='{.items[0].metadata.name}')

  # View logs
  kubectl logs $POD -n carepath-demo

  # Look for:
  # - "Loading Qwen model for the first time..." (if model not pre-downloaded)
  # - "Model loaded successfully"
  # - No error messages
  ```

- [ ] Test health endpoint
  ```bash
  # Get LoadBalancer URL
  LB_URL=$(kubectl get service chat-api-service -n carepath-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

  # Test health
  curl http://$LB_URL/health
  ```

- [ ] Test triage endpoint with real LLM
  ```bash
  curl -X POST http://$LB_URL/triage \
    -H "Content-Type: application/json" \
    -d '{
      "patient_mrn": "MRN-001",
      "query": "What is my current diagnosis?"
    }'

  # Verify response uses real LLM (not mock response)
  ```

- [ ] Monitor metrics
  - [ ] Check pod CPU/memory usage
    ```bash
    kubectl top pods -n carepath-demo -l app=chat-api
    ```

  - [ ] Watch for HPA scaling if CPU goes above 60%
    ```bash
    kubectl get hpa -n carepath-demo
    ```

  - [ ] Check response latency (should be higher than mock mode)

- [ ] Load test (optional)
  ```bash
  # Run a few concurrent requests to test performance
  # Use k6, Locust, or simple bash script
  for i in {1..10}; do
    curl -X POST http://$LB_URL/triage \
      -H "Content-Type: application/json" \
      -d "{\"patient_mrn\":\"MRN-001\",\"query\":\"Test $i\"}" &
  done
  wait
  ```

---

## Rollback Procedure (If Needed)

If issues are detected after deployment:

- [ ] Identify the issue
  - [ ] Check pod logs for errors
  - [ ] Review error rate metrics
  - [ ] Check user reports

- [ ] Execute rollback
  ```bash
  # Quick rollback to previous version
  kubectl rollout undo deployment/chat-api -n carepath-demo

  # Or revert Terraform changes and re-apply
  # Edit terraform.tfvars back to old image
  make tf-apply
  ```

- [ ] Verify rollback success
  ```bash
  kubectl rollout status deployment/chat-api -n carepath-demo
  kubectl get pods -n carepath-demo -l app=chat-api
  ```

- [ ] Update ConfigMap if needed
  ```bash
  # If you need to switch LLM_MODE back to mock
  kubectl set env deployment/chat-api LLM_MODE=mock -n carepath-demo
  ```

---

## Post-Deployment Cleanup

- [ ] Update documentation
  - [ ] Mark deployment date in changelog
  - [ ] Update README if usage changes
  - [ ] Document any issues encountered

- [ ] Monitor for 24-48 hours
  - [ ] Watch error rates
  - [ ] Check costs (CPU usage may increase)
  - [ ] Gather user feedback

- [ ] Optimize if needed
  - [ ] Adjust HPA settings if autoscaling is too aggressive/conservative
  - [ ] Tune model generation parameters (temperature, max_tokens)
  - [ ] Consider GPU instances if CPU inference is too slow

---

## Notes

- **First startup**: If model is not pre-downloaded in the image, the first pod startup will take 5-15 minutes to download the ~8GB model
- **Subsequent pods**: Model downloads independently to each pod's ephemeral storage (unless using shared PVC)
- **HPA behavior**: CPU usage will be higher with real LLM, may trigger autoscaling to max replicas
- **Cost impact**: Larger instances (t3.large/xlarge) will increase costs
- **Alternative**: Consider moving to GPU instances (g4dn.xlarge) for better LLM performance in future

---

## Success Criteria

Deployment is considered successful when:

- [ ] All chat-api pods are in `Running` state
- [ ] Health endpoint returns 200 OK
- [ ] Triage endpoint returns LLM-generated responses (not mock)
- [ ] Response latency is acceptable (<10s for CPU inference)
- [ ] No errors in pod logs
- [ ] HPA is functioning correctly
- [ ] No user-reported issues
