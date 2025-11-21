# App Module Outputs

output "namespace" {
  description = "Kubernetes namespace for the application"
  value       = kubernetes_namespace.carepath.metadata[0].name
}

output "db_api_service_name" {
  description = "Name of the db-api service"
  value       = kubernetes_service.db_api.metadata[0].name
}

output "chat_api_service_name" {
  description = "Name of the chat-api service"
  value       = kubernetes_service.chat_api.metadata[0].name
}

output "chat_api_load_balancer_hostname" {
  description = "Load balancer hostname for chat-api service"
  value       = try(kubernetes_service.chat_api.status[0].load_balancer[0].ingress[0].hostname, "")
}

output "chat_api_load_balancer_ip" {
  description = "Load balancer IP for chat-api service"
  value       = try(kubernetes_service.chat_api.status[0].load_balancer[0].ingress[0].ip, "")
}
