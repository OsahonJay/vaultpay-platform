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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

data "terraform_remote_state" "aws" {
  backend = "s3"
  config = {
    bucket = "vaultpay-terraform-state-dev"
    key    = "dev/aws/terraform.tfstate"
    region = "eu-west-2"
  }
}

data "aws_eks_cluster" "main" {
  name = data.terraform_remote_state.aws.outputs.cluster_name
}

data "aws_eks_cluster_auth" "main" {
  name = data.terraform_remote_state.aws.outputs.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

module "platform_service" {
  source = "../../modules/platform-service"

  service_name      = "secret-reader"
  environment       = "dev"
  container_image   = "875522883478.dkr.ecr.eu-west-2.amazonaws.com/vaultpay/secret-reader:1.0.1"
  container_port    = 8080
  secret_name       = "vaultpay/dev/app-secret"
  oidc_provider_arn = data.terraform_remote_state.aws.outputs.oidc_provider_arn
  oidc_provider_url = data.terraform_remote_state.aws.outputs.oidc_provider_url
  namespace         = "vaultpay"
}

module "falco" {
  source = "../../modules/falco"
}
