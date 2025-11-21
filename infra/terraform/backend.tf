# Terraform backend configuration for remote state
# S3 bucket and DynamoDB table must be created beforehand

terraform {
  backend "s3" {
    # These values should be configured via backend config file or CLI
    # Example: terraform init -backend-config="bucket=my-tf-state-bucket"
    bucket         = ""  # Set via backend config
    key            = "carepath/terraform.tfstate"
    region         = ""  # Set via backend config
    encrypt        = true
    dynamodb_table = ""  # Set via backend config for state locking
  }

  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.14"
    }
  }
}
