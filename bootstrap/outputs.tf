output "state_bucket" {
  description = "Bucket to use in the environments' backend configuration."
  value       = aws_s3_bucket.state.bucket
}

output "plan_role_arn" {
  description = "Set as the AWS_PLAN_ROLE_ARN repository variable."
  value       = module.github_plan.role_arn
}

output "apply_role_arn" {
  description = "Set as the AWS_APPLY_ROLE_ARN variable of the dev/prod GitHub environments."
  value       = module.github_apply.role_arn
}

output "account_id" {
  description = "Account where the bootstrap ran."
  value       = data.aws_caller_identity.current.account_id
}
