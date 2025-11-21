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

  depends_on = [module.network]
}

# MongoDB Atlas Module
module "mongo_atlas" {
  source = "../../modules/mongo_atlas"

  org_id       = var.mongodb_atlas_org_id
  project_name = "${var.name_prefix}-project"
  cluster_name = "${var.name_prefix}-cluster"
  aws_region   = var.aws_region

  instance_size    = var.mongodb_instance_size
  mongodb_version  = var.mongodb_version
  backup_enabled   = var.mongodb_backup_enabled

  db_username     = var.mongodb_username
  db_password     = var.mongodb_password
  database_name   = var.mongodb_database_name

  environment         = var.environment
  allow_all_ips       = var.mongodb_allow_all_ips
}

# App Module (Kubernetes Resources)
module "app" {
  source = "../../modules/app"

  namespace   = var.app_namespace
  environment = var.environment

  # MongoDB Configuration
  mongodb_connection_string = module.mongo_atlas.connection_string
  mongodb_db_name           = var.mongodb_database_name

  # Docker Images
  db_api_image   = var.db_api_image
  chat_api_image = var.chat_api_image

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

  depends_on = [module.eks, module.mongo_atlas]
}
