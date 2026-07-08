output "service_role_arn" {
  description = "IAM role ARN for the service"
  value       = aws_iam_role.service.arn
}

output "service_account_name" {
  description = "Kubernetes ServiceAccount name"
  value       = kubernetes_service_account.service.metadata[0].name
}

output "service_name" {
  description = "Kubernetes Service name"
  value       = kubernetes_service.service.metadata[0].name
}
