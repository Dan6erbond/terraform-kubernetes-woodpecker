output "service_name" {
  description = "Service name for Woodpecker server deployment"
  value       = kubernetes_service.woodpecker_server.metadata.0.name
}

output "service_http_port" {
  description = "HTTP port exposed by the service"
  value       = kubernetes_service.woodpecker_server.spec.0.port.0.name
}

output "service_grpc_port" {
  description = "GRPC port exposed by the service"
  value       = kubernetes_service.woodpecker_server.spec.0.port.1.name
}
