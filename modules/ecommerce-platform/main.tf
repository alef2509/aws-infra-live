# The e-commerce saga platform on AWS: one VPC, one public ALB, one ECS cluster,
# MSK Serverless, and four services each with its own PostgreSQL database
# (database-per-service), all built from the versioned modules.

locals {
  name = "shop-${var.environment}"

  # Kafka client settings for MSK IAM authentication, passed as Spring Boot
  # relaxed-binding environment variables (spring.kafka.properties.*).
  kafka_iam_env = {
    KAFKA_BOOTSTRAP_SERVERS                                    = module.kafka.bootstrap_brokers_sasl_iam
    SPRING_KAFKA_PROPERTIES_SECURITY_PROTOCOL                  = "SASL_SSL"
    SPRING_KAFKA_PROPERTIES_SASL_MECHANISM                     = "AWS_MSK_IAM"
    SPRING_KAFKA_PROPERTIES_SASL_JAAS_CONFIG                   = "software.amazon.msk.auth.iam.IAMLoginModule required;"
    SPRING_KAFKA_PROPERTIES_SASL_CLIENT_CALLBACK_HANDLER_CLASS = "software.amazon.msk.auth.iam.IAMClientCallbackHandler"
  }

  services = {
    order-service = {
      port      = 8081
      database  = "orders"
      public    = { path_patterns = ["/api/v1/orders", "/api/v1/orders/*"], priority = 10 }
      extra_env = {}
    }
    inventory-service = {
      port      = 8082
      database  = "inventory"
      public    = { path_patterns = ["/api/v1/products", "/api/v1/products/*"], priority = 20 }
      extra_env = {}
    }
    payment-service = {
      port      = 8083
      database  = "payment"
      public    = null
      extra_env = { PAYMENT_GATEWAY_URL = var.payment_gateway_url }
    }
    shipping-service = {
      port      = 8084
      database  = "shipping"
      public    = null
      extra_env = {}
    }
  }
}

# One "client" security group per service, created here rather than inside the
# service module: databases and Kafka allow these groups, and the services carry
# them. Referencing the service module's own group instead would create a
# dependency cycle (service needs the DB secret, DB needs the service's group).
resource "aws_security_group" "client" {
  # checkov:skip=CKV2_AWS_5: attached to the ECS services through module.service (additional_security_group_ids)
  for_each = local.services

  name_prefix = "${local.name}-${each.key}-client-"
  description = "Identifies ${each.key} as a client of its database and Kafka"
  vpc_id      = module.network.vpc_id
  tags        = merge(var.tags, { Name = "${local.name}-${each.key}-client", Service = each.key })

  lifecycle {
    create_before_destroy = true
  }
}

module "network" {
  source = "git::https://github.com/alef2509/terraform-aws-modules.git//modules/network?ref=aca5c01d4d4a7a8dd2415a811f768571cba8b41e" # v1.0.0

  name                     = local.name
  cidr_block               = var.cidr_block
  nat_gateway_mode         = var.nat_gateway_mode
  flow_logs_retention_days = var.log_retention_days
  tags                     = var.tags
}

module "alb" {
  source = "git::https://github.com/alef2509/terraform-aws-modules.git//modules/alb?ref=aca5c01d4d4a7a8dd2415a811f768571cba8b41e" # v1.0.0

  name                = local.name
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.public_subnet_ids
  certificate_arn     = var.certificate_arn
  deletion_protection = var.database.deletion_protection
  tags                = var.tags
}

module "cluster" {
  source = "git::https://github.com/alef2509/terraform-aws-modules.git//modules/ecs-cluster?ref=aca5c01d4d4a7a8dd2415a811f768571cba8b41e" # v1.0.0

  name                = local.name
  fargate_spot_weight = var.fargate_spot_weight
  tags                = var.tags
}

module "kafka" {
  source = "git::https://github.com/alef2509/terraform-aws-modules.git//modules/msk-serverless?ref=aca5c01d4d4a7a8dd2415a811f768571cba8b41e" # v1.0.0

  name                       = local.name
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_subnet_ids
  allowed_security_group_ids = [for sg in aws_security_group.client : sg.id]
  tags                       = var.tags
}

module "database" {
  source   = "git::https://github.com/alef2509/terraform-aws-modules.git//modules/rds-postgres?ref=aca5c01d4d4a7a8dd2415a811f768571cba8b41e" # v1.0.0
  for_each = local.services

  identifier                 = "${local.name}-${each.value.database}"
  database_name              = each.value.database
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_subnet_ids
  allowed_security_group_ids = [aws_security_group.client[each.key].id]
  instance_class             = var.database.instance_class
  multi_az                   = var.database.multi_az
  deletion_protection        = var.database.deletion_protection
  backup_retention_days      = var.database.backup_retention_days
  tags                       = merge(var.tags, { Service = each.key })
}

module "service" {
  source   = "git::https://github.com/alef2509/terraform-aws-modules.git//modules/ecs-service?ref=aca5c01d4d4a7a8dd2415a811f768571cba8b41e" # v1.0.0
  for_each = local.services

  name               = each.key
  cluster_arn        = module.cluster.arn
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
  image              = "${var.image_registry}/${each.key}:${var.image_tag}"
  container_port     = each.value.port
  autoscaling        = var.service_scaling
  desired_count      = var.service_scaling.min_capacity
  log_retention_days = var.log_retention_days

  additional_security_group_ids = [aws_security_group.client[each.key].id]

  environment = merge(local.kafka_iam_env, each.value.extra_env, {
    DB_URL       = module.database[each.key].jdbc_url
    OUTBOX_RELAY = "polling" # no Kafka Connect on AWS: the in-app relay publishes the outbox
  })
  secrets = {
    DB_USERNAME = "${module.database[each.key].master_user_secret_arn}:username::"
    DB_PASSWORD = "${module.database[each.key].master_user_secret_arn}:password::"
  }
  task_role_policy_json = module.kafka.client_policy_json

  load_balancer = each.value.public == null ? null : {
    listener_arn      = module.alb.listener_arn
    security_group_id = module.alb.security_group_id
    path_patterns     = each.value.public.path_patterns
    priority          = each.value.public.priority
  }

  tags = merge(var.tags, { Service = each.key })
}
