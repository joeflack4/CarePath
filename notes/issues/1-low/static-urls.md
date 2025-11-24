From a report 2025/11/24:

is there any (easy) way in aws to just get static load balancer urls? why this dynamism? i
 don't like that they change

⏺ Good question! The dynamic nature of AWS load balancer DNS names is intentional, but
  there are definitely better solutions. Let me explain why they change and your options:

  Why Load Balancer DNS Names Change

  The DNS name changes because Kubernetes LoadBalancer services create new AWS ELB/NLB
  resources when certain configuration changes occur. Common triggers:
  - Service recreated (what happened to us during terraform apply)
  - Service type changed
  - LoadBalancer annotations modified
  - Service deleted and recreated

  The DNS name is tied to the physical AWS load balancer resource, so new resource = new
  DNS name.

  Solutions (Ranked by Ease)

  1. Use AWS Route53 with a Custom Domain ⭐ (Best Practice)

  Effort: ~30 minutes
  Cost: ~$0.50/month per hosted zone + $12/year for domain

  This is the standard production approach:

  # infra/terraform/modules/dns/main.tf
  resource "aws_route53_record" "chat_api" {
    zone_id = var.hosted_zone_id
    name    = "chat-api.carepath.io"
    type    = "CNAME"
    ttl     = 300
    records = [var.chat_api_lb_hostname]
  }

  Pros:
  - Stable URL that never changes: http://chat-api.carepath.io
  - Professional appearance
  - Can add SSL/TLS certificates
  - Easy to remember

  Cons:
  - Requires owning a domain
  - Small ongoing cost

  ---
  2. Use Kubernetes Service with Static Service Name (What we already have)

  Effort: 0 (already implemented)
  Cost: $0

  Actually, the LoadBalancer DNS name only changes when the Kubernetes Service resource is
   recreated. Our current setup is fine - the issue we hit was a one-time thing during
  infrastructure changes.

  Looking at our Terraform:
  # infra/terraform/modules/app/main.tf
  resource "kubernetes_service" "chat_api" {
    metadata {
      name = "chat-api-service"  # Static name
    }
    # ...
  }

  The LB URL should be stable as long as we don't recreate the Service resource.

  Pros:
  - Free
  - No additional configuration
  - Already working

  Cons:
  - Ugly URLs
  - Can change if Service is recreated

  ---
  3. Use AWS Network Load Balancer with Static IP

  Effort: ~1 hour (Terraform changes)
  Cost: ~$16/month for static IPs

  Change from Classic/Application LB to Network LB with static Elastic IPs:

  resource "kubernetes_service" "chat_api" {
    metadata {
      annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
        "service.beta.kubernetes.io/aws-load-balancer-eip-allocations" = join(",",
  aws_eip.nlb[*].id)
      }
    }
    # ...
  }

  Pros:
  - Static IP addresses that never change
  - Can use IP directly or with DNS

  Cons:
  - More expensive
  - Still need DNS for human-readable URLs
  - More complex setup

  ---
  4. Use Kubernetes Ingress Controller (Modern Approach)

  Effort: 2-3 hours
  Cost: ~$16/month for ALB + potential domain costs

  Use AWS ALB Ingress Controller with a single load balancer for all services:

  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: carepath-ingress
  spec:
    rules:
    - host: api.carepath.io
      http:
        paths:
        - path: /chat
          backend:
            service:
              name: chat-api-service
        - path: /db
          backend:
            service:
              name: db-api-service

  Pros:
  - One load balancer for all services (cost savings)
  - Path-based routing
  - Modern Kubernetes pattern
  - Stable DNS

  Cons:
  - Requires ingress controller setup
  - Still benefits from custom domain

  ---
  My Recommendation

  For your demo environment: Stick with what we have + the auto-deploy fix I just
  implemented. The LoadBalancer URL is now stable and won't change unless you specifically
   recreate the Service resource.

  For production: Use Option 1 (Route53 + Custom Domain). It's the cleanest solution:

  # Users access via:
  https://api.carepath.io/chat/triage
  https://api.carepath.io/db/patients

  # Frontend points to:
  VITE_CHAT_API_URL=https://api.carepath.io/chat
  VITE_DB_API_URL=https://api.carepath.io/db

  Would you like me to implement the Route53 + custom domain setup? It's pretty
  straightforward if you have a domain (or we can register one for ~$12/year).
