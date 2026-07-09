variable "service_name" {
  description = "Name of the service — used to name all Kubernetes and AWS resources"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.service_name))
    error_message = "Service name must be lowercase, start with a letter, and be 3-31 characters."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "container_image" {
  description = "Full container image URI including tag — must be from approved ECR registry"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "secret_name" {
  description = "AWS Secrets Manager secret name this service requires access to"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider without https://"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into"
  type        = string
  default     = "vaultpay"
}

variable "replicas" {
  description = "Number of pod replicas"
  type        = number
  default     = 1
}

variable "resources" {
  description = "Container resource requests and limits"
  type = object({
    requests_cpu    = string
    requests_memory = string
    limits_cpu      = string
    limits_memory   = string
  })
  default = {
    requests_cpu    = "50m"
    requests_memory = "64Mi"
    limits_cpu      = "100m"
    limits_memory   = "128Mi"
  }
}
