# ECR Module - Container registries for CarePath services

resource "aws_ecr_repository" "db_api" {
  name                 = "carepath-db-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # Allow deletion even with images present

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name    = "carepath-db-api"
    Service = "db-api"
  }
}

resource "aws_ecr_repository" "chat_api" {
  name                 = "carepath-chat-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # Allow deletion even with images present

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name    = "carepath-chat-api"
    Service = "chat-api"
  }
}

# Lifecycle policy to keep only last N images
resource "aws_ecr_lifecycle_policy" "db_api" {
  repository = aws_ecr_repository.db_api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "chat_api" {
  repository = aws_ecr_repository.chat_api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
