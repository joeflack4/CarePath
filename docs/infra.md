# Infrastructure Operations Guide

This guide covers day-to-day operations for managing deployed CarePath infrastructure. For initial deployment, see [Deployment Guide](deploy.md).

## Table of Contents

1. [Viewing Logs](#viewing-logs)
2. [Monitoring & Status](#monitoring--status)
3. [Scaling](#scaling)
4. [Rollbacks](#rollbacks)
5. [Restarts](#restarts)
6. [Troubleshooting](#troubleshooting)

---

## Viewing Logs

### Quick Commands

| Command | Description |
|---------|-------------|
| `make k8s-logs-chat` | Stream chat-api logs (live) |
| `make k8s-logs-db` | Stream db-api logs (live) |
| `make k8s-logs-chat-errors` | Show only errors from chat-api |
| `make k8s-logs-db-errors` | Show only errors from db-api |
| `make k8s-logs-all-errors` | Show errors from all services |
| `make k8s-logs s=chat-api` | Stream logs for specific service |

### Examples

**Stream chat-api logs (Ctrl+C to stop):**
```bash
make k8s-logs-chat
```

**Check for errors across all services:**
```bash
make k8s-logs-all-errors
```

**View logs for a specific pod:**
```bash
kubectl logs <pod-name> -n carepath-demo
```

**View previous container logs (after crash):**
```bash
kubectl logs <pod-name> -n carepath-demo --previous
```

---

## Monitoring & Status

### Service Status

```bash
# Full status overview (deployments, pods, services, HPA)
make k8s-status

# List all pods with details
make k8s-pods-list

# Get service URLs
make k8s-get-urls
```

### Health Checks

```bash
# Test chat-api health
curl http://<CHAT_API_URL>/health

# Test db-api health (if exposed)
curl http://<DB_API_URL>/health

# Test triage endpoint
make test-triage m="What are my medications?"
```

### Pod Details

```bash
# Describe a pod (shows events, errors, resource usage)
kubectl describe pod <pod-name> -n carepath-demo

# Get pod resource usage
kubectl top pods -n carepath-demo
```

---

## Scaling

### Manual Scaling

```bash
# Scale chat-api to 3 replicas
make k8s-scale-up s=chat-api r=3

# Scale db-api to 2 replicas
make k8s-scale-up s=db-api r=2

# Scale down to 1 replica
make k8s-scale-down s=chat-api r=1
```

### Check HPA Status

```bash
# View Horizontal Pod Autoscaler status
kubectl get hpa -n carepath-demo

# Detailed HPA info
kubectl describe hpa -n carepath-demo
```

---

## Rollbacks

### Quick Rollback

```bash
# Rollback chat-api to previous version
make k8s-rollback-chat

# Rollback db-api to previous version
make k8s-rollback-db-api

# Rollback both services
make k8s-rollback-all
```

### View Rollout History

```bash
# See deployment history for all services
make k8s-history

# Detailed history for specific deployment
kubectl rollout history deployment/chat-api -n carepath-demo
```

### Rollback to Specific Revision

```bash
# Rollback to revision 2
kubectl rollout undo deployment/chat-api -n carepath-demo --to-revision=2
```

---

## Restarts

### Rolling Restart (Zero Downtime)

```bash
# Restart chat-api pods
make k8s-restart-chat

# Restart db-api pods
make k8s-restart-db-api
```

### Force Restart (Delete Pods)

```bash
# Delete all pods for a deployment (they will recreate)
kubectl delete pods -l app=chat-api -n carepath-demo
```

---

## Troubleshooting

### Common Issues

#### 500 Internal Server Error

1. **Check logs for errors:**
   ```bash
   make k8s-logs-all-errors
   ```

2. **Check if pods are healthy:**
   ```bash
   make k8s-status
   ```

3. **Describe the pod for events:**
   ```bash
   kubectl describe pod -l app=chat-api -n carepath-demo
   ```

#### Pods Not Starting

1. **Check pod status:**
   ```bash
   kubectl get pods -n carepath-demo
   ```

2. **Check pod events:**
   ```bash
   kubectl describe pod <pod-name> -n carepath-demo
   ```

3. **Common causes:**
   - Image pull errors (check ECR permissions)
   - Resource limits exceeded
   - Health check failures
   - Secret/ConfigMap issues

#### Service Unreachable

1. **Check service exists:**
   ```bash
   kubectl get svc -n carepath-demo
   ```

2. **Check LoadBalancer status:**
   ```bash
   kubectl describe svc chat-api-service -n carepath-demo
   ```

3. **Check if pods are ready:**
   ```bash
   kubectl get pods -n carepath-demo
   ```

#### MongoDB Connection Issues

1. **Check pod logs for connection errors:**
   ```bash
   make k8s-logs-db-errors
   ```

2. **Verify secret exists:**
   ```bash
   kubectl get secret mongodb-secret -n carepath-demo
   ```

3. **Check MongoDB Atlas:**
   - Verify IP whitelist includes EKS node IPs (or 0.0.0.0/0 for demo)
   - Verify connection string is correct

### Useful kubectl Commands

```bash
# Get all resources in namespace
kubectl get all -n carepath-demo

# Watch pods in real-time
kubectl get pods -n carepath-demo -w

# Execute command in pod
kubectl exec -it <pod-name> -n carepath-demo -- /bin/sh

# Port-forward to local machine (for debugging)
kubectl port-forward svc/chat-api-service 8000:80 -n carepath-demo
```

---

## Command Reference

| Command | Description |
|---------|-------------|
| `make k8s-status` | Show all deployments, pods, services, HPA |
| `make k8s-pods-list` | List all pods with details |
| `make k8s-get-urls` | Get service URLs |
| `make k8s-logs-chat` | Stream chat-api logs |
| `make k8s-logs-db` | Stream db-api logs |
| `make k8s-logs-all-errors` | Show errors from all services |
| `make k8s-scale-up s=SERVICE r=N` | Scale up to N replicas |
| `make k8s-scale-down s=SERVICE r=N` | Scale down to N replicas |
| `make k8s-rollback-chat` | Rollback chat-api |
| `make k8s-rollback-db-api` | Rollback db-api |
| `make k8s-restart-chat` | Rolling restart chat-api |
| `make k8s-restart-db-api` | Rolling restart db-api |
| `make k8s-history` | View rollout history |

---

## Related Documentation

- [Deployment Guide](deploy.md) - Initial deployment and setup
- [Rollout Options](deploy-rollout-options.md) - Deployment strategies
