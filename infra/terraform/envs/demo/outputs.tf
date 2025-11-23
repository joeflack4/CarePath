# Demo Environment Outputs

# Network Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.network.public_subnet_ids
}

# ECR Outputs
output "db_api_repo_url" {
  description = "ECR repository URL for db-api"
  value       = module.ecr.db_api_repo_url
}

output "chat_api_repo_url" {
  description = "ECR repository URL for chat-api"
  value       = module.ecr.chat_api_repo_url
}

# EKS Outputs
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

# App Outputs
output "app_namespace" {
  description = "Kubernetes namespace"
  value       = module.app.namespace
}

output "chat_api_load_balancer_hostname" {
  description = "Load balancer hostname for chat-api"
  value       = module.app.chat_api_load_balancer_hostname
}

output "chat_api_load_balancer_ip" {
  description = "Load balancer IP for chat-api"
  value       = module.app.chat_api_load_balancer_ip
}

output "db_api_load_balancer_hostname" {
  description = "Load balancer hostname for db-api (when expose_db_api=true)"
  value       = module.app.db_api_load_balancer_hostname
}

output "db_api_load_balancer_ip" {
  description = "Load balancer IP for db-api (when expose_db_api=true)"
  value       = module.app.db_api_load_balancer_ip
}

# kubectl configuration command
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# Frontend Outputs
output "frontend_bucket_name" {
  description = "S3 bucket name for frontend"
  value       = var.expose_frontend ? module.frontend[0].bucket_name : ""
}

output "frontend_url" {
  description = "Frontend URL (CloudFront if enabled, otherwise S3 website)"
  value       = var.expose_frontend ? module.frontend[0].frontend_url : ""
}

output "frontend_cloudfront_url" {
  description = "CloudFront URL for frontend (HTTPS) - empty if CloudFront disabled"
  value       = var.expose_frontend ? module.frontend[0].cloudfront_url : ""
}

output "frontend_cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation) - empty if CloudFront disabled"
  value       = var.expose_frontend ? module.frontend[0].cloudfront_distribution_id : ""
}
