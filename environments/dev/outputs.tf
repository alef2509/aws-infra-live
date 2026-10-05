output "url" {
  description = "Public entry point."
  value       = module.platform.url
}

output "database_endpoints" {
  description = "Database endpoint per service."
  value       = module.platform.database_endpoints
}
