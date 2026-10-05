# prod: high availability and protection over cost.
module "platform" {
  source = "../../modules/ecommerce-platform"

  environment         = "prod"
  cidr_block          = "10.20.0.0/16"
  nat_gateway_mode    = "one_per_az"
  certificate_arn     = var.certificate_arn
  image_registry      = "ghcr.io/alef2509"
  image_tag           = var.image_tag
  payment_gateway_url = var.payment_gateway_url
  fargate_spot_weight = 0
  log_retention_days  = 90

  service_scaling = {
    min_capacity       = 2
    max_capacity       = 10
    target_cpu_percent = 60
  }

  database = {
    instance_class        = "db.m7g.large"
    multi_az              = true
    deletion_protection   = true
    backup_retention_days = 14
  }
}
