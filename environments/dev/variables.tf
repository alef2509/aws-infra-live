variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "allowed_account_ids" {
  description = "AWS account(s) this environment may be deployed to."
  type        = list(string)
}

variable "image_tag" {
  description = "Version of the service images to deploy."
  type        = string
}

variable "payment_gateway_url" {
  description = "Base URL of the payment provider."
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate for the public endpoint (null for HTTP only)."
  type        = string
  default     = null
}
