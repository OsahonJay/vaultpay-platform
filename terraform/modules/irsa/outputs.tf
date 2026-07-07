output "workload_role_arn" {
  description = "IAM role ARN for the workload — used to annotate the Kubernetes ServiceAccount"
  value       = aws_iam_role.workload.arn
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.app_secret.arn
}
