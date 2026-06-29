terraform {
  backend "s3" {
    bucket         = "vaultpay-terraform-state-dev"
    key            = "dev/networking/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "vaultpay-terraform-locks-dev"
  }
}
