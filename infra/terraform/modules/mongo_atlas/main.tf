# MongoDB Atlas Module - Managed MongoDB cluster

resource "mongodbatlas_project" "main" {
  name   = var.project_name
  org_id = var.org_id
}

resource "mongodbatlas_cluster" "main" {
  project_id   = mongodbatlas_project.main.id
  name         = var.cluster_name
  cluster_type = "REPLICASET"

  # Provider settings
  provider_name               = "AWS"
  provider_region_name        = var.aws_region
  provider_instance_size_name = var.instance_size

  # Backup configuration
  backup_enabled               = var.backup_enabled
  auto_scaling_disk_gb_enabled = true

  # MongoDB version
  mongo_db_major_version = var.mongodb_version

  tags {
    key   = "Environment"
    value = var.environment
  }

  tags {
    key   = "Project"
    value = "CarePath"
  }
}

# Database User
resource "mongodbatlas_database_user" "main" {
  username           = var.db_username
  password           = var.db_password
  project_id         = mongodbatlas_project.main.id
  auth_database_name = "admin"

  roles {
    role_name     = "readWrite"
    database_name = var.database_name
  }

  scopes {
    name = mongodbatlas_cluster.main.name
    type = "CLUSTER"
  }
}

# Network Access - IP Whitelist
resource "mongodbatlas_project_ip_access_list" "eks" {
  count = length(var.eks_nat_gateway_ips)

  project_id = mongodbatlas_project.main.id
  ip_address = var.eks_nat_gateway_ips[count.index]
  comment    = "IP from EKS NAT Gateway ${count.index}"
}

# Allow access from anywhere for demo (remove in production!)
resource "mongodbatlas_project_ip_access_list" "allow_all" {
  count = var.allow_all_ips ? 1 : 0

  project_id = mongodbatlas_project.main.id
  cidr_block = "0.0.0.0/0"
  comment    = "Allow all IPs (DEMO ONLY - REMOVE IN PRODUCTION)"
}
