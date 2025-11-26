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

variable "expose_db_api" {
  description = "Whether to expose db-api externally via LoadBalancer (true) or keep internal via ClusterIP (false)"
  type        = bool
  default     = false
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

# Hugging Face Inference API Configuration
variable "hf_api_token" {
  description = "Hugging Face API token for Router API"
  type        = string
  sensitive   = true
}

variable "hf_qwen_model_id" {
  description = "HF model ID with provider (e.g., Qwen/Qwen2.5-7B-Instruct:together)"
  type        = string
  default     = "Qwen/Qwen2.5-7B-Instruct:together"
}

variable "hf_timeout_seconds" {
  description = "HF API request timeout in seconds"
  type        = number
  default     = 30
}

variable "hf_max_new_tokens" {
  description = "Max tokens to generate"
  type        = number
  default     = 256
}

variable "hf_temperature" {
  description = "Sampling temperature"
  type        = number
  default     = 0.7
}
