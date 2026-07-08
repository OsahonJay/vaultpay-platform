terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

data "aws_eks_cluster" "main" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

module "networking" {
  source      = "../../modules/networking"
  environment = "dev"
  vpc_cidr    = "10.0.0.0/16"
}

module "eks" {
  source = "../../modules/eks"

  environment        = "dev"
  private_subnet_ids = module.networking.private_subnet_ids
}

module "irsa" {
  source = "../../modules/irsa"

  environment          = "dev"
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  namespace            = "default"
  service_account_name = "vaultpay-app-sa"
}

module "platform_service" {
  source = "../../modules/platform-service"

  service_name      = "secret-reader"
  environment       = "dev"
  container_image   = "875522883478.dkr.ecr.eu-west-2.amazonaws.com/vaultpay/secret-reader:1.0.1"
  container_port    = 8080
  secret_name       = "vaultpay/dev/app-secret"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  namespace         = "default"
}
