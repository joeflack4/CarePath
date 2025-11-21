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
  default     = "1.28"
}

variable "node_instance_types" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 6
}

# MongoDB Atlas Configuration
variable "mongodb_atlas_org_id" {
  description = "MongoDB Atlas organization ID"
  type        = string
}

variable "mongodb_atlas_public_key" {
  description = "MongoDB Atlas API public key"
  type        = string
}

variable "mongodb_atlas_private_key" {
  description = "MongoDB Atlas API private key"
  type        = string
  sensitive   = true
}

variable "mongodb_instance_size" {
  description = "MongoDB Atlas instance size"
  type        = string
  default     = "M10"
}

variable "mongodb_version" {
  description = "MongoDB version"
  type        = string
  default     = "7.0"
}

variable "mongodb_backup_enabled" {
  description = "Enable MongoDB backups"
  type        = bool
  default     = true
}

variable "mongodb_username" {
  description = "MongoDB database username"
  type        = string
  default     = "carepath_admin"
}

variable "mongodb_password" {
  description = "MongoDB database password"
  type        = string
  sensitive   = true
}

variable "mongodb_database_name" {
  description = "MongoDB database name"
  type        = string
  default     = "carepath"
}

variable "mongodb_allow_all_ips" {
  description = "Allow all IPs to access MongoDB (demo only)"
  type        = bool
  default     = true
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
  default     = 3
}

variable "chat_api_replicas" {
  description = "Number of chat-api replicas"
  type        = number
  default     = 3
}

# HPA Configuration
variable "hpa_min_replicas" {
  description = "Minimum replicas for HPA"
  type        = number
  default     = 3
}

variable "hpa_max_replicas" {
  description = "Maximum replicas for HPA"
  type        = number
  default     = 6
}

variable "hpa_target_cpu_utilization" {
  description = "Target CPU utilization for HPA"
  type        = number
  default     = 60
}

# Application Settings
variable "llm_mode" {
  description = "LLM mode (mock or qwen)"
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

# Provider-level variables (used by providers.tf)
variable "create_eks" {
  description = "Whether to create EKS cluster"
  type        = bool
  default     = true
}
