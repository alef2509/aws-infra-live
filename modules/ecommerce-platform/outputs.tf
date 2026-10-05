output "url" {
  description = "Public entry point."
  value       = "${var.certificate_arn != null ? "https" : "http"}://${module.alb.dns_name}"
}

output "cluster_name" {
  description = "ECS cluster."
  value       = module.cluster.name
}

output "kafka_bootstrap_servers" {
  description = "MSK Serverless bootstrap servers (SASL/IAM)."
  value       = module.kafka.bootstrap_brokers_sasl_iam
}

output "database_endpoints" {
  description = "Database endpoint per service."
  value       = { for k, db in module.database : k => db.endpoint }
}
