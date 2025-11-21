# Deployment Rollout Options

This document describes different strategies for deploying new versions of the CarePath AI services, particularly when introducing changes like a new LLM model.

---

## Option 1: Rolling Update (Default Kubernetes Strategy)

### Description
Replace all pods one at a time with the new version until all pods are running the new version. This is Kubernetes' default deployment strategy.

### How It Works
1. New version of the image is pushed to ECR
2. Deployment manifest is updated with new image tag
3. Kubernetes creates a new pod with the new version
4. Once the new pod is healthy (passes readiness probes), Kubernetes terminates one old pod
5. Process repeats until all pods are replaced
6. At any given time, both old and new versions may be serving traffic

### Pros
- Built into Kubernetes - no additional infrastructure needed
- Zero downtime deployment
- Automatic rollback capability via `kubectl rollout undo`
- Resource efficient - doesn't require double the pods

### Cons
- Both old and new versions run simultaneously during rollout
- If new version has a bug, some traffic will hit it before rollback
- Limited control over traffic distribution

### Implementation
```bash
# Update terraform.tfvars with new image tag
db_api_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/carepath-chat-api:v2.0"

# Apply the change
cd infra/terraform/envs/demo && terraform apply

# Or use make target
make deploy-chat

# Monitor rollout
kubectl rollout status deployment/chat-api -n carepath-demo

# Rollback if needed
kubectl rollout undo deployment/chat-api -n carepath-demo
```

### Configuration
In Terraform deployment spec:
```hcl
spec {
  strategy {
    type = "RollingUpdate"
    rolling_update {
      max_surge       = 1  # Max number of extra pods during update
      max_unavailable = 0  # Max number of pods that can be unavailable
    }
  }
}
```

---

## Option 2: Canary Deployment (Traffic Splitting)

### Description
Deploy the new version alongside the old version and gradually shift traffic from old to new using percentage-based routing.

### How It Works
1. Deploy new version as a separate deployment (e.g., `chat-api-v2`)
2. Use service mesh (Istio, Linkerd) or ingress controller to split traffic:
   - Start: 95% to old version, 5% to new version
   - Monitor metrics, error rates, latency
   - Gradually increase traffic to new version: 10%, 25%, 50%, 75%, 100%
   - Once 100% traffic is on new version, remove old deployment

### Pros
- Gradual exposure of new version to users
- Can limit blast radius of bugs
- Detailed control over traffic distribution
- Can route specific users/requests to new version for testing
- Easy to halt rollout and rollback

### Cons
- Requires service mesh or advanced ingress controller
- More complex infrastructure
- Requires monitoring and manual intervention
- Higher resource usage (both versions running simultaneously)
- Need to maintain compatibility between versions

### Implementation Requirements
- **Service Mesh**: Install Istio or Linkerd on EKS cluster
- **Monitoring**: Prometheus + Grafana to track metrics by version
- **Traffic Splitting Configuration**: VirtualService (Istio) or TrafficSplit (SMI)

### Example with Istio
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: chat-api
spec:
  hosts:
  - chat-api
  http:
  - match:
    - headers:
        x-version:
          exact: "canary"
    route:
    - destination:
        host: chat-api-v2
      weight: 100
  - route:
    - destination:
        host: chat-api-v1
      weight: 90
    - destination:
        host: chat-api-v2
      weight: 10
```

---

## Option 3: Blue-Green Deployment (Separate Environments)

### Description
Maintain two complete, identical environments (staging/blue and production/green). Deploy to staging first, then switch traffic entirely when ready.

### How It Works
1. **Staging Environment**: Deploy new version to staging cluster/namespace
2. **Testing**: Run full test suite against staging
3. **Traffic Switch**: Update DNS or load balancer to point to staging
4. **Monitoring**: Watch metrics closely after switch
5. **Rollback**: If issues arise, switch DNS back to production
6. **Cleanup**: Once stable, promote staging to production, prepare for next deployment

### Pros
- Complete isolation between versions
- Full testing on production-like environment before traffic switch
- Instant rollback by switching DNS/load balancer
- Zero downtime if done correctly
- Can keep old version running for safety

### Cons
- Requires double the infrastructure (most expensive option)
- Database migrations can be complex
- DNS/load balancer switch may not be instant (DNS TTL)
- Need to manage state between environments
- Resource intensive

### Implementation
```hcl
# Two complete environment configurations in Terraform
# infra/terraform/envs/staging/
# infra/terraform/envs/production/

# Deploy to staging
cd infra/terraform/envs/staging && terraform apply

# Run tests against staging
kubectl get service chat-api-service -n carepath-staging

# Switch traffic (update Route53 or ALB target group)
# aws elbv2 modify-listener ...

# Promote staging to production after validation
```

---

## Recommendation for CarePath AI

For the current MVP phase with limited resources, we recommend **Option 1: Rolling Update**.

### Why?
1. **No Additional Infrastructure**: Already supported by Kubernetes
2. **Low Complexity**: Terraform changes only
3. **Cost Effective**: No extra clusters or service mesh
4. **Good Enough**: For MVP with limited users, rolling updates provide sufficient safety
5. **Easy Rollback**: `kubectl rollout undo` is simple and fast

### When to Evolve?
Consider Option 2 (Canary) or Option 3 (Blue-Green) when:
- User base grows significantly (>10,000 daily users)
- Downtime becomes expensive (SLA requirements)
- Need to test with real traffic before full rollout
- Have resources to maintain more complex infrastructure
- Compliance requires full environment separation

---

## Rollback Strategies

Regardless of deployment method, always have a rollback plan:

### Rolling Update Rollback
```bash
kubectl rollout undo deployment/chat-api -n carepath-demo
```

### Canary Rollback
```bash
# Set traffic back to 100% old version
kubectl apply -f traffic-split-old-100percent.yaml
```

### Blue-Green Rollback
```bash
# Update DNS or load balancer back to previous environment
aws route53 change-resource-record-sets ...
```

---

## Monitoring During Rollouts

Key metrics to watch during any deployment:

1. **Error Rate**: Track 5xx errors per service version
2. **Latency**: p50, p95, p99 response times
3. **Pod Health**: Readiness/liveness probe failures
4. **Resource Usage**: CPU, memory spikes
5. **Business Metrics**: Successful triage requests, user complaints

### Example Queries (Prometheus)
```promql
# Error rate by version
rate(http_requests_total{status=~"5..", deployment="chat-api"}[5m])

# Latency by version
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Pod restarts
rate(kube_pod_container_status_restarts_total{namespace="carepath-demo"}[5m])
```
