terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
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

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  value = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
}




