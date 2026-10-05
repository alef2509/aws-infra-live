provider "aws" {
  region = var.region

  # Guard rail: refuse to run against any account other than the expected one.
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = {
      Project     = "ecommerce-saga"
      Environment = "prod"
      ManagedBy   = "terraform"
      Repository  = "github.com/alef2509/aws-infra-live"
    }
  }
}
