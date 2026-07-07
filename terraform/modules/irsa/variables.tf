variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider (without https://)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the workload"
  type        = string
  default     = "default"
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount name"
  type        = string
  default     = "vaultpay-app-sa"
}
