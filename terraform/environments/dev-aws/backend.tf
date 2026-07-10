terraform {
  backend "s3" {
    bucket       = "vaultpay-terraform-state-dev"
    key          = "dev/aws/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
