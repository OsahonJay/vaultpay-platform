terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_kms_key" "dynamodb" {
  description             = "KMS key for Terraform lock table encryption - ${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "vaultpay-dynamodb-locks-key-${var.environment}"
    environment = var.environment
    managed-by  = "terraform"
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "vaultpay-terraform-state-${var.environment}"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name                = "vaultpay-terraform-state-${var.environment}"
    environment         = var.environment
    managed-by          = "terraform"
    cost-centre         = "platform"
    data-classification = "restricted"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "vaultpay-terraform-locks-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "vaultpay-terraform-locks-${var.environment}"
    environment = var.environment
    managed-by  = "terraform"
    cost-centre = "platform"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_sns_topic" "state_bucket_alerts" {
  name              = "vaultpay-state-bucket-alerts-${var.environment}"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    environment = var.environment
    managed-by  = "terraform"
  }
}

resource "aws_sns_topic_policy" "state_bucket_alerts" {
  arn = aws_sns_topic.state_bucket_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
      Action   = "SNS:Publish"
      Resource = aws_sns_topic.state_bucket_alerts.arn
      Condition = {
        ArnLike = {
          "aws:SourceArn" = aws_s3_bucket.terraform_state.arn
        }
      }
    }]
  })
}

resource "aws_s3_bucket_notification" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  topic {
    topic_arn = aws_sns_topic.state_bucket_alerts.arn
    events    = ["s3:ObjectRemoved:*"]
  }

  depends_on = [aws_sns_topic_policy.state_bucket_alerts]
}

data "aws_caller_identity" "current" {}
