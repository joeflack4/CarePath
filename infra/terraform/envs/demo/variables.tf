# Demo Environment Variables

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "carepath-demo"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones"
  type        = number
  default     = 2
}

# EKS Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "carepath-demo-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "node_instance_types" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "node_capacity_type" {
  description = "Capacity type for worker nodes: ON_DEMAND or SPOT (SPOT is cheaper and uses different quota)"
  type        = string
  default     = "ON_DEMAND"
}

# MongoDB Configuration (using existing Atlas cluster)
variable "mongodb_uri" {
  description = "MongoDB connection URI for existing Atlas cluster"
  type        = string
  sensitive   = true
}

variable "mongodb_database_name" {
  description = "MongoDB database name"
  type        = string
  default     = "carepath"
}

# Application Configuration
variable "app_namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "carepath-demo"
}

variable "db_api_image" {
  description = "Docker image for db-api"
  type        = string
  default     = "REPLACE_WITH_ECR_URL:latest"
}

variable "chat_api_image" {
  description = "Docker image for chat-api"
  type        = string
  default     = "REPLACE_WITH_ECR_URL:latest"
}

variable "db_api_replicas" {
  description = "Number of db-api replicas"
  type        = number
  default     = 1
}

variable "chat_api_replicas" {
  description = "Number of chat-api replicas"
  type        = number
  default     = 1
}

# HPA Configuration
variable "hpa_min_replicas" {
  description = "Minimum replicas for HPA"
  type        = number
  default     = 1
}

variable "hpa_max_replicas" {
  description = "Maximum replicas for HPA"
  type        = number
  default     = 3
}

variable "hpa_target_cpu_utilization" {
  description = "Target CPU utilization for HPA"
  type        = number
  default     = 60
}

# Chat API Resource Configuration (for LLM deployment)
variable "chat_api_cpu_request" {
  description = "CPU request for chat-api pods"
  type        = string
  default     = "100m"
}

variable "chat_api_memory_request" {
  description = "Memory request for chat-api pods"
  type        = string
  default     = "256Mi"
}

variable "chat_api_cpu_limit" {
  description = "CPU limit for chat-api pods"
  type        = string
  default     = "500m"
}

variable "chat_api_memory_limit" {
  description = "Memory limit for chat-api pods"
  type        = string
  default     = "512Mi"
}

# Application Settings
variable "llm_mode" {
  description = "LLM mode (mock, qwen, or Qwen3-4B-Thinking-2507)"
  type        = string
  default     = "mock"
}

variable "vector_mode" {
  description = "Vector mode (mock or pinecone)"
  type        = string
  default     = "mock"
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "INFO"
}

variable "expose_db_api" {
  description = "Whether to expose db-api externally via LoadBalancer (true) or keep internal via ClusterIP (false)"
  type        = bool
  default     = true  # Exposed for demo environment
}

# Frontend Configuration
variable "expose_frontend" {
  description = "Whether to deploy the frontend S3/CloudFront infrastructure"
  type        = bool
  default     = true
}

variable "frontend_bucket_name" {
  description = "S3 bucket name for frontend static files"
  type        = string
  default     = "carepath-demo-frontend"
}

# LLM Model Cache Configuration
variable "enable_model_cache_pvc" {
  description = "Whether to create a PersistentVolumeClaim for LLM model caching"
  type        = bool
  default     = false
}

variable "model_cache_storage_size" {
  description = "Size of the model cache PVC (should be at least 10Gi for Qwen3-4B)"
  type        = string
  default     = "15Gi"
}

# Provider-level variables (used by providers.tf)
variable "create_eks" {
  description = "Whether to create EKS cluster"
  type        = bool
  default     = true
}
