# MongoDB Atlas Module Variables

variable "org_id" {
  description = "MongoDB Atlas Organization ID"
  type        = string
}

variable "project_name" {
  description = "Name of the MongoDB Atlas project"
  type        = string
}

variable "cluster_name" {
  description = "Name of the MongoDB cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region for MongoDB Atlas cluster"
  type        = string
}

variable "instance_size" {
  description = "Instance size for MongoDB cluster (e.g., M10, M20, M30)"
  type        = string
  default     = "M10"
}

variable "mongodb_version" {
  description = "MongoDB version"
  type        = string
  default     = "7.0"
}

variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "carepath"
}

variable "environment" {
  description = "Environment name (e.g., demo, staging, production)"
  type        = string
}

variable "eks_nat_gateway_ips" {
  description = "List of NAT gateway IPs from EKS to whitelist"
  type        = list(string)
  default     = []
}

variable "allow_all_ips" {
  description = "Allow access from all IPs (DEMO ONLY - set to false in production)"
  type        = bool
  default     = false
}
