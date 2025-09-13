# Development Environment Configuration

environment = "dev"
location    = "eastus2"
secondary_location = "westus2"

project_name = "fabric-platform"
cost_center  = "IT-DataPlatform"

# Fabric Configuration - Smaller capacity for dev
fabric_capacity_sku = "F4"
fabric_admin_users = [
  "admin@yourcompany.com",
  "dataeng@yourcompany.com"
]

# Networking - Dev uses public endpoints for easier access
enable_bastion = false
allowed_ip_ranges = [
  "0.0.0.0/0"  # Open for dev - restrict in higher environments
]
enable_private_endpoints = false

# API Management
api_publisher_email = "api-admin@yourcompany.com"
api_publisher_name  = "Data Platform Team"

# Alerts - Minimal alerting for dev
critical_alert_emails = ["dataplatform-dev@yourcompany.com"]
warning_alert_emails  = ["dataplatform-dev@yourcompany.com"]
critical_alert_phones = []

# Feature Flags - Optimize for cost in dev
enable_diagnostic_logs   = true
enable_threat_detection  = false
enable_auto_scaling     = false
enable_geo_redundancy   = false
enable_disaster_recovery = false

# Data Retention - Shorter retention for dev
log_retention_days    = 7
backup_retention_days = 7
archive_after_days   = 30

# Performance - Minimal resources for dev
event_hub_throughput_units = 2
cosmos_db_max_throughput   = 4000
sql_pool_performance_level = "DW100c"

# ML Configuration - Minimal compute for dev
ml_compute_min_nodes = 0
ml_compute_max_nodes = 2

# Security
enable_cmk_encryption   = false
security_contact_email  = "security-dev@yourcompany.com"
security_contact_phone  = "+1-555-0100"

# Compliance - Basic compliance for dev
compliance_standards = ["ISO-27001"]

# Budget - Dev environment budget
monthly_budget_amount = 5000
budget_alert_thresholds = [80, 100]

tags = {
  Owner       = "Data Platform Team"
  Environment = "Development"
  Purpose     = "Development and Testing"
  AutoShutdown = "true"
  StartTime   = "8:00"
  StopTime    = "18:00"
}