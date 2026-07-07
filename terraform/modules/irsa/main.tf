data "aws_caller_identity" "current" {}

# The secret this workload will access
resource "aws_secretsmanager_secret" "app_secret" {
  name        = "vaultpay/${var.environment}/app-secret"
  description = "Application secret for VaultPay workload - ${var.environment}"

  tags = {
    Name                = "vaultpay-${var.environment}-app-secret"
    environment         = var.environment
    managed-by          = "terraform"
    data-classification = "restricted"
  }
}

resource "aws_secretsmanager_secret_version" "app_secret" {
  secret_id = aws_secretsmanager_secret.app_secret.id
  secret_string = jsonencode({
    api_key = "vaultpay-demo-key-${var.environment}"
    db_host = "db.vaultpay.internal"
  })
}

# IAM role for the workload — assumed via IRSA
resource "aws_iam_role" "workload" {
  name = "${var.environment}-vaultpay-workload-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    environment = var.environment
    managed-by  = "terraform"
  }
}

# Least privilege — only GetSecretValue and DescribeSecret on this one secret
resource "aws_iam_role_policy" "workload_secrets" {
  name = "${var.environment}-vaultpay-workload-secrets-policy"
  role = aws_iam_role.workload.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:eu-west-2:${data.aws_caller_identity.current.account_id}:secret:vaultpay/${var.environment}/app-secret-*"
    }]
  })
}
