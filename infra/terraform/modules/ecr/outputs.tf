# ECR Module Outputs

output "db_api_repo_url" {
  description = "Repository URL for db-api container images"
  value       = aws_ecr_repository.db_api.repository_url
}

output "chat_api_repo_url" {
  description = "Repository URL for chat-api container images"
  value       = aws_ecr_repository.chat_api.repository_url
}

output "db_api_repo_arn" {
  description = "ARN of db-api ECR repository"
  value       = aws_ecr_repository.db_api.arn
}

output "chat_api_repo_arn" {
  description = "ARN of chat-api ECR repository"
  value       = aws_ecr_repository.chat_api.arn
}
