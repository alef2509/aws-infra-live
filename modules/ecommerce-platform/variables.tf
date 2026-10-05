variable "environment" {
  description = "Environment name (dev, prod...)."
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR."
  type        = string
}

variable "nat_gateway_mode" {
  description = "none, single or one_per_az."
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate for HTTPS; null serves HTTP only."
  type        = string
  default     = null
}

variable "image_registry" {
  description = "Registry and namespace of the service images, e.g. ghcr.io/alef2509."
  type        = string
}

variable "image_tag" {
  description = "Tag (or digest) deployed for every service."
  type        = string
}

variable "payment_gateway_url" {
  description = "Base URL of the external payment provider."
  type        = string
}

variable "fargate_spot_weight" {
  description = "Share of tasks on Fargate Spot."
  type        = number
  default     = 0
}

variable "service_scaling" {
  description = "Autoscaling bounds shared by the services."
  type = object({
    min_capacity       = number
    max_capacity       = number
    target_cpu_percent = number
  })
}

variable "database" {
  description = "Sizing and protection of the per-service databases."
  type = object({
    instance_class        = string
    multi_az              = bool
    deletion_protection   = bool
    backup_retention_days = number
  })
}

variable "log_retention_days" {
  description = "Retention of logs."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}
