terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name            = "${var.environment}-vaultpay-vpc"
    environment     = var.environment
    managed-by      = "terraform"
    cost-centre     = "platform"
    data-classification = "confidential"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name            = "${var.environment}-public-${local.azs[count.index]}"
    environment     = var.environment
    managed-by      = "terraform"
    cost-centre     = "platform"
    data-classification = "public"
    "kubernetes.io/role/elb" = "1"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 3)
  availability_zone = local.azs[count.index]

  tags = {
    Name            = "${var.environment}-private-${local.azs[count.index]}"
    environment     = var.environment
    managed-by      = "terraform"
    cost-centre     = "platform"
    data-classification = "confidential"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-vaultpay-igw"
    environment = var.environment
    managed-by  = "terraform"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count  = 3
  domain = "vpc"

  tags = {
    Name        = "${var.environment}-nat-eip-${count.index}"
    environment = var.environment
    managed-by  = "terraform"
  }
}

# NAT Gateway — one per AZ for HA
resource "aws_nat_gateway" "main" {
  count         = 3
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.environment}-nat-${local.azs[count.index]}"
    environment = var.environment
    managed-by  = "terraform"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-public-rt"
    environment = var.environment
    managed-by  = "terraform"
  }
}

# Private Route Tables — one per AZ
resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${var.environment}-private-rt-${local.azs[count.index]}"
    environment = var.environment
    managed-by  = "terraform"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn

  tags = {
    Name        = "${var.environment}-vaultpay-flow-logs"
    environment = var.environment
    managed-by  = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vaultpay/${var.environment}/vpc-flow-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.flow_logs.arn

  tags = {
    environment = var.environment
    managed-by  = "terraform"
  }
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.environment}-vaultpay-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = {
    environment = var.environment
    managed-by  = "terraform"
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.environment}-vaultpay-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-vaultpay-default-sg-locked"
    environment = var.environment
    managed-by  = "terraform"
  }
}
resource "aws_kms_key" "flow_logs" {
  description             = "KMS key for VPC Flow Logs encryption - ${var.environment}"
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
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.eu-west-2.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-vaultpay-flow-logs-key"
    environment = var.environment
    managed-by  = "terraform"
  }
}

data "aws_caller_identity" "current" {}


