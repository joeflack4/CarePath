# MongoDB Atlas Module Outputs

output "connection_string" {
  description = "MongoDB connection string"
  value       = "mongodb+srv://${var.db_username}:${var.db_password}@${mongodbatlas_cluster.main.connection_strings[0].standard_srv}"
  sensitive   = true
}

output "cluster_name" {
  description = "Name of the MongoDB cluster"
  value       = mongodbatlas_cluster.main.name
}

output "project_id" {
  description = "MongoDB Atlas project ID"
  value       = mongodbatlas_project.main.id
}

output "cluster_id" {
  description = "MongoDB cluster ID"
  value       = mongodbatlas_cluster.main.cluster_id
}
