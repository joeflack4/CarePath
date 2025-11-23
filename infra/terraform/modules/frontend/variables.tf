# Frontend Module Variables

variable "bucket_name" {
  description = "Name of the S3 bucket for frontend static files"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., demo, staging, prod)"
  type        = string
}

variable "enable_cloudfront" {
  description = "Whether to create CloudFront distribution (requires verified AWS account). Set to false for S3-only hosting."
  type        = bool
  default     = false
}
