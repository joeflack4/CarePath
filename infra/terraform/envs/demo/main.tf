# Demo Environment Configuration for CarePath

terraform {
  backend "s3" {
    # Backend configuration should be provided via backend config file
    # Example: terraform init -backend-config="backend.hcl"
  }
}

# Network Module
module "network" {
  source = "../../modules/network"

  name_prefix  = var.name_prefix
  vpc_cidr     = var.vpc_cidr
  az_count     = var.az_count
  cluster_name = var.cluster_name
}

# ECR Module
module "ecr" {
  source = "../../modules/ecr"
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  public_subnet_ids  = module.network.public_subnet_ids

  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_capacity_type  = var.node_capacity_type

  depends_on = [module.network]
}

# MongoDB: Using existing Atlas cluster via mongodb_uri variable
# No Terraform-managed Atlas resources needed

# App Module (Kubernetes Resources)
module "app" {
  source = "../../modules/app"

  namespace   = var.app_namespace
  environment = var.environment

  # MongoDB Configuration (uses existing Atlas cluster)
  mongodb_connection_string = var.mongodb_uri
  mongodb_db_name           = var.mongodb_database_name

  # Docker Images - use ECR repository URLs with :latest tag
  db_api_image   = "${module.ecr.db_api_repo_url}:latest"
  chat_api_image = "${module.ecr.chat_api_repo_url}:latest"

  # Replica Configuration
  db_api_replicas  = var.db_api_replicas
  chat_api_replicas = var.chat_api_replicas

  # HPA Configuration
  hpa_min_replicas            = var.hpa_min_replicas
  hpa_max_replicas            = var.hpa_max_replicas
  hpa_target_cpu_utilization  = var.hpa_target_cpu_utilization

  # Application Configuration
  llm_mode    = var.llm_mode
  vector_mode = var.vector_mode
  log_level   = var.log_level

  # Service Exposure
  expose_db_api = var.expose_db_api

  depends_on = [module.eks]
}

# Frontend Module (S3 + CloudFront)
module "frontend" {
  source = "../../modules/frontend"
  count  = var.expose_frontend ? 1 : 0

  bucket_name = var.frontend_bucket_name
  environment = var.environment
}
