# VaultPay Platform Service Module

## What This Does

This module deploys a fully compliant service to the VaultPay platform.
A developer provides six inputs. The platform automatically creates everything
required to run a secure, PCI-DSS aligned service on EKS.

## What Gets Created

- **Kubernetes Deployment** — runs your container with hardened security settings
- **Kubernetes Service** — internal ClusterIP endpoint for service-to-service communication
- **Kubernetes ServiceAccount** — workload identity annotated for IRSA
- **NetworkPolicy** — restricts ingress to namespace only, blocks all egress
- **IAM Role** — assumed via IRSA, scoped to this service only
- **IAM Policy** — least-privilege access to the specified Secrets Manager secret

## Security Guarantees (Automatic)

Every service deployed through this module automatically gets:

- `allowPrivilegeEscalation: false` — no privilege escalation inside the container
- `runAsNonRoot: true` — container must run as non-root user
- `readOnlyRootFilesystem: true` — filesystem is read-only
- IRSA with a scoped IAM role — no node-level credential sharing
- NetworkPolicy blocking all egress — compromised pods cannot call out
- ClusterIP only — no direct external access

## Usage

```hcl
module "my_service" {
  source = "../../modules/platform-service"

  service_name      = "payment-processor"
  environment       = "dev"
  container_image   = "875522883478.dkr.ecr.eu-west-2.amazonaws.com/vaultpay/payment-processor:1.0.0"
  container_port    = 8080
  secret_name       = "vaultpay/dev/payment-processor-secret"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  namespace         = "default"
}
```

## Requirements

- Container image must come from VaultPay's approved ECR registry
- Container must run as a non-root numeric UID (e.g. USER 1001 in Dockerfile)
- The specified Secrets Manager secret must exist before applying

## Inputs

| Name | Description | Required |
|------|-------------|----------|
| service_name | Lowercase service name, 3-31 chars | Yes |
| environment | dev, staging, or production | Yes |
| container_image | Full ECR image URI with tag | Yes |
| container_port | Port the container listens on | No (default 8080) |
| secret_name | Secrets Manager secret path | Yes |
| oidc_provider_arn | EKS OIDC provider ARN | Yes |
| oidc_provider_url | EKS OIDC provider URL without https:// | Yes |
| namespace | Kubernetes namespace | No (default: default) |
| replicas | Number of pod replicas | No (default: 1) |
| resources | CPU and memory requests/limits | No (see defaults) |

## Outputs

| Name | Description |
|------|-------------|
| service_role_arn | IAM role ARN for the service |
| service_account_name | Kubernetes ServiceAccount name |
| service_name | Kubernetes Service name |
