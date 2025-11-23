# Frontend Module Outputs

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.frontend.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.frontend.arn
}

output "website_url" {
  description = "S3 website endpoint URL (HTTP only)"
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "cloudfront_url" {
  description = "CloudFront distribution URL (HTTPS) - empty if CloudFront disabled"
  value       = var.enable_cloudfront ? "https://${aws_cloudfront_distribution.frontend[0].domain_name}" : ""
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation) - empty if CloudFront disabled"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.frontend[0].id : ""
}

output "frontend_url" {
  description = "Primary frontend URL (CloudFront if enabled, otherwise S3)"
  value       = var.enable_cloudfront ? "https://${aws_cloudfront_distribution.frontend[0].domain_name}" : "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}
