# Remote state in S3 with native locking (use_lockfile, Terraform >= 1.10: no DynamoDB table).
# The bucket is created once by ../../bootstrap.
terraform {
  backend "s3" {
    bucket       = "alef2509-terraform-state"
    key          = "ecommerce/dev/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
