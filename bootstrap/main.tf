# Run once per account, with local state, by an administrator:
#   terraform init && terraform apply
# Creates the remote-state bucket and the roles GitHub Actions assumes via OIDC.

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# ---------------- State bucket ----------------

resource "aws_s3_bucket" "state" {
  # checkov:skip=CKV_AWS_144: cross-region replication is not needed for a state bucket in this setup
  # checkov:skip=CKV_AWS_18: access logging of the state bucket is left to CloudTrail data events
  # checkov:skip=CKV2_AWS_62: no event notifications needed on state changes
  # checkov:skip=CKV_AWS_145: SSE-S3 is sufficient here; switch to SSE-KMS with a CMK if required
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled" # recover from a corrupted or deleted state
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_tls_only.json
}

# ---------------- GitHub Actions roles ----------------

# Pull requests may only read: plan with ReadOnlyAccess plus the state lock file.
data "aws_iam_policy_document" "plan_state" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }
  statement {
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*.tflock"]
  }
}

module "github_plan" {
  source = "git::https://github.com/alef2509/terraform-aws-modules.git//modules/github-oidc?ref=aca5c01d4d4a7a8dd2415a811f768571cba8b41e" # v1.0.0

  role_name           = "github-aws-infra-live-plan"
  subjects            = ["repo:${var.github_repository}:pull_request"]
  managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  inline_policy_json  = data.aws_iam_policy_document.plan_state.json
}

# Applies only from protected GitHub environments (required reviewers).
module "github_apply" {
  source = "git::https://github.com/alef2509/terraform-aws-modules.git//modules/github-oidc?ref=aca5c01d4d4a7a8dd2415a811f768571cba8b41e" # v1.0.0

  role_name            = "github-aws-infra-live-apply"
  create_oidc_provider = false
  subjects             = [for env in ["dev", "prod"] : "repo:${var.github_repository}:environment:${env}"]
  managed_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]

  depends_on = [module.github_plan]
}
