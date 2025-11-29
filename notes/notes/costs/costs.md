# AWS Cost Analysis - CarePath Demo Environment

**Date**: 2025-11-28
**Current Run Rate**: $140 for 6 days = **~$700/month** 🚨

---

## Current Cost Breakdown (Per Month)

### Fixed Infrastructure Costs

| Service | Unit Cost | Hours/Month | Monthly Cost | Notes |
|---------|-----------|-------------|--------------|-------|
| **EKS Control Plane** | $0.10/hr | 730 | **$73** | Required for Kubernetes cluster |
| **NAT Gateway** (2 AZs) | $0.045/hr × 2 | 730 | **$66** | Allows private pods to reach internet |
| **Elastic IPs** (2 for NAT) | $0.005/hr × 2 | 730 | **$7** | Static IPs for NAT gateways |
| **Load Balancers** (2) | $0.0225/hr × 2 | 730 | **$33** | db-api and chat-api services |
| **r5.large EC2** | $0.126/hr | 730 | **$92** | EKS worker node (16GB RAM for LLM) |
| **EBS Volumes** | ~$0.10/GB-month | 15GB + root | **$5** | Model cache PVC + root volume |
| **CloudWatch Logs** | Free tier | <5GB | **$0** | 96% of free tier used (4.8/5 GB) |
| **Subtotal (infrastructure)** | | | **$276** | Minimum baseline costs |

### Variable Costs (The Real Problem)

| Service | Usage | Unit Cost | Monthly Cost | Status |
|---------|-------|-----------|--------------|--------|
| **NAT Gateway Data Processing** | ~9.4 TB/month | $0.045/GB | **$424** | 🚨 MAJOR ISSUE |
| **Data Transfer Out** | After first 100GB | $0.09/GB | Variable | Included in NAT processing |
| **CloudWatch over free tier** | 0.3 GB expected | $0.50/GB | **~$0.15** | Will exceed soon |

### Total Current Costs

**Estimated Total**: **$700+/month**

---

## The Data Transfer Problem 🚨

You're transferring **~233 GB/day** through the NAT Gateway. This is extremely unusual for a low-traffic demo application.

### Possible Causes

1. **Container image pulls** from public registries (not ECR)?
2. **Log shipping** to external service (Datadog, Splunk, etc.)?
3. **MongoDB Atlas traffic** (large data sync/queries)?
4. **CloudFront origin requests** (frontend fetching from somewhere)?
5. **HuggingFace API responses** (unlikely - API responses are KB, not GB)
6. **Kubernetes pulling images** repeatedly (bad image pull policy)?

### Investigation Needed

**Action**: Check AWS Cost Explorer → Data Transfer → Group by Service to identify source

---

## Cost Optimization Options

### Option 1: Minimal Changes (Keep NAT, Downsize Instance)

**Changes:**
- Switch from `r5.large` → `t3.small` (HuggingFace API doesn't need 16GB RAM)
- Disable 4 of 5 EKS logs (keep only `audit`)
- Remove model cache PVC (not needed for external HF hosting)
- Reduce to 1 AZ instead of 2 (cuts NAT costs in half)

**Monthly Savings:**
- EC2: $92 → $15 (**saves $77**)
- NAT Gateway: $66 → $33 (**saves $33**)
- Elastic IP: $7 → $4 (**saves $3**)
- EBS: $5 → $2 (**saves $3**)
- CloudWatch: negligible

**New Total (if data transfer fixed)**: ~$161/month on-demand
**New Total (current data usage)**: ~$585/month (still expensive!)

**SPOT pricing**: t3.small spot ~$4.50/month (saves additional $10)

---

### Option 2: Remove NAT Gateway (Public Subnet Deployment)

⚠️ **Requires architecture change** - move EKS nodes to public subnets

**Changes:**
- Move worker nodes to public subnets (they get public IPs)
- Remove NAT Gateway entirely
- Pods reach HuggingFace API directly without NAT
- Use security groups to restrict access

**Monthly Savings:**
- NAT Gateway: $66 → $0 (**saves $66**)
- NAT data processing: $424 → $0 (**saves $424**)
- Elastic IPs: $7 → $0 (**saves $7**)

**New Total (assuming no NAT needed)**: ~$123/month on-demand

**Risk**: Public IPs on nodes, need careful security group configuration

---

### Option 3: Alternative Architecture (Cheaper Than EKS)

EKS is expensive for low-traffic demos. Consider:

| Service | Monthly Cost | Pros | Cons |
|---------|--------------|------|------|
| **ECS Fargate** | ~$40-60 | No node management, pay per task | Different deployment model |
| **AWS App Runner** | ~$25-40 | Simplest, auto-scaling | Less control |
| **Lightsail Containers** | $7-40 | Flat rate, predictable | Limited scaling |
| **Current EKS** | $700+ | Full K8s features | Very expensive |

---

### Option 4: Shut Down When Not In Use

**Best for demo/portfolio projects:**

- `terraform destroy` when not demoing (**$0/month**)
- `terraform apply` to rebuild when needed (~10-15 minutes)
- Only pay for hours actually used

**Monthly cost if used 8 hours/week**: ~$77/month (11% uptime)

---

## Optimized Configuration Recommendations

### Immediate Actions (No Downtime)

1. ✅ **Investigate data transfer costs** (AWS Cost Explorer)
2. ✅ **Switch to t3.small instance** (HF-only doesn't need 16GB RAM)
3. ✅ **Disable unnecessary EKS logs** (keep only `audit`)
4. ✅ **Remove model cache PVC** (not needed for external hosting)
5. ✅ **Reduce to 1 AZ** (cut NAT costs in half)

**Files to modify:**
- `infra/terraform/envs/demo/terraform.tfvars`
- `infra/terraform/modules/eks/main.tf`

---

### Long-term Considerations

1. **Fix data transfer issue first** - this is the #1 cost driver
2. **Consider public subnet deployment** if NAT is main cost
3. **Evaluate ECS Fargate or App Runner** for simpler/cheaper architecture
4. **Implement auto-shutdown** for non-business hours if keeping EKS
5. **Use Spot instances** for worker nodes (65% discount, minimal risk for demo)

---

## Cost Comparison: Current vs. Optimized

| Configuration | Monthly Cost | Savings |
|---------------|--------------|---------|
| **Current (r5.large, 2 AZ, with data transfer issue)** | **$700** | baseline |
| **Optimized (t3.small, 1 AZ, data transfer issue fixed)** | **$161** | **$539 (77%)** |
| **Optimized + SPOT** | **$151** | **$549 (78%)** |
| **Public subnet (no NAT)** | **$123** | **$577 (82%)** |
| **Destroy when unused (8hrs/week uptime)** | **$77** | **$623 (89%)** |
| **Full shutdown** | **$0** | **$700 (100%)** |

---

## Shutdown Options

### Option A: Scale to Zero (Partial Savings)
- Scale EKS node group to 0 replicas
- **Saves**: EC2 costs (~$92/month)
- **Still pay**: EKS control plane, NAT, Load Balancers (~$180/month)
- **Spin up time**: ~2 minutes

### Option B: Terraform Destroy (Full Savings)
- Destroy entire infrastructure
- **Saves**: Everything ($700/month)
- **Still pay**: $0 (only S3 state storage ~$0.02/month)
- **Spin up time**: ~10-15 minutes
- **Risk**: Must recreate all resources

---

## Files Modified for Optimization

### `infra/terraform/envs/demo/terraform.tfvars`
```hcl
# Change instance type
node_instance_types = ["t3.small"]  # was: ["r5.large"]

# Optional: Use spot for additional savings
node_capacity_type = "SPOT"  # was: "ON_DEMAND"

# Remove model cache (not needed for HF)
enable_model_cache_pvc = false  # was: true

# Reduce resource limits
chat_api_cpu_request    = "250m"   # was: "1000m"
chat_api_memory_request = "512Mi"  # was: "4Gi"
chat_api_cpu_limit      = "500m"   # was: "2000m"
chat_api_memory_limit   = "1Gi"    # was: "8Gi"
```

### `infra/terraform/modules/eks/main.tf`
```hcl
# Line 60 - Reduce logging
enabled_cluster_log_types = ["audit"]  # was: ["api", "audit", "authenticator", "controllerManager", "scheduler"]
```

### `infra/terraform/modules/network/main.tf`
```hcl
# Reduce to 1 AZ (requires variable change)
# In network module variables or main.tf call
az_count = 1  # was: 2
```

---

## Next Steps

1. **Immediate**: Check AWS Cost Explorer to identify data transfer source
2. **Short-term**: Implement optimizations (t3.small, reduce logs, 1 AZ)
3. **Medium-term**: Fix data transfer issue or remove NAT gateway
4. **Long-term**: Consider shutting down when not actively demoing, or migrate to cheaper service

**Estimated time to implement optimizations**: 1-2 hours
**Estimated monthly savings**: $400-600/month
