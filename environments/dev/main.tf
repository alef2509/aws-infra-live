# dev: cheapest setup that still exercises every component.
module "platform" {
  source = "../../modules/ecommerce-platform"

  environment         = "dev"
  cidr_block          = "10.10.0.0/16"
  nat_gateway_mode    = "single"
  certificate_arn     = var.certificate_arn
  image_registry      = "ghcr.io/alef2509"
  image_tag           = var.image_tag
  payment_gateway_url = var.payment_gateway_url
  fargate_spot_weight = 70
  log_retention_days  = 14

  service_scaling = {
    min_capacity       = 1
    max_capacity       = 2
    target_cpu_percent = 70
  }

  database = {
    instance_class        = "db.t4g.micro"
    multi_az              = false
    deletion_protection   = true # destroying even dev data must be a deliberate change
    backup_retention_days = 1
  }
}
