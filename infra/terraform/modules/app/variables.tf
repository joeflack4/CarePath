# App Module Variables

variable "namespace" {
  description = "Kubernetes namespace for CarePath app"
  type        = string
  default     = "carepath-demo"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# MongoDB Configuration
variable "mongodb_connection_string" {
  description = "MongoDB connection string"
  type        = string
  sensitive   = true
}

variable "mongodb_db_name" {
  description = "MongoDB database name"
  type        = string
  default     = "carepath"
}

# Application Images
variable "db_api_image" {
  description = "Docker image for db-api service"
  type        = string
}

variable "chat_api_image" {
  description = "Docker image for chat-api service"
  type        = string
}

# Replica Configuration
variable "db_api_replicas" {
  description = "Number of replicas for db-api deployment"
  type        = number
  default     = 3
}

variable "chat_api_replicas" {
  description = "Number of replicas for chat-api deployment"
  type        = number
  default     = 3
}

# Resource Requests and Limits - DB API
variable "db_api_cpu_request" {
  description = "CPU request for db-api pods"
  type        = string
  default     = "100m"
}

variable "db_api_memory_request" {
  description = "Memory request for db-api pods"
  type        = string
  default     = "256Mi"
}

variable "db_api_cpu_limit" {
  description = "CPU limit for db-api pods"
  type        = string
  default     = "500m"
}

variable "db_api_memory_limit" {
  description = "Memory limit for db-api pods"
  type        = string
  default     = "512Mi"
}

# Resource Requests and Limits - Chat API
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

# HPA Configuration
variable "hpa_min_replicas" {
  description = "Minimum number of replicas for HPA"
  type        = number
  default     = 3
}

variable "hpa_max_replicas" {
  description = "Maximum number of replicas for HPA"
  type        = number
  default     = 6
}

variable "hpa_target_cpu_utilization" {
  description = "Target CPU utilization percentage for HPA"
  type        = number
  default     = 60
}

# Application Configuration
variable "llm_mode" {
  description = "LLM mode (mock or qwen)"
  type        = string
  default     = "mock"
}

variable "vector_mode" {
  description = "Vector database mode (mock or pinecone)"
  type        = string
  default     = "mock"
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "INFO"
}
