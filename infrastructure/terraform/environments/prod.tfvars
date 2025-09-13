# Production Environment Configuration

environment = "prod"
location    = "eastus2"
secondary_location = "westus2"

project_name = "fabric-platform"
cost_center  = "IT-DataPlatform"

# Fabric Configuration - Full capacity for production
fabric_capacity_sku = "F64"
fabric_admin_users = [
  "prod-admin@yourcompany.com",
  "dataplatform-team@yourcompany.com",
  "ml-team@yourcompany.com"
]

# Networking - Strict security for production
enable_bastion = true
allowed_ip_ranges = [
  "203.0.113.0/24",    # Corporate office IP range
  "198.51.100.0/24",   # VPN gateway range
  "172.16.0.0/12"      # Private network range
]
enable_private_endpoints = true

# API Management
api_publisher_email = "api-prod@yourcompany.com"
api_publisher_name  = "Your Company Data Platform"

# Alerts - Comprehensive alerting for production
critical_alert_emails = [
  "dataplatform-oncall@yourcompany.com",
  "sre-team@yourcompany.com",
  "management@yourcompany.com"
]
warning_alert_emails = [
  "dataplatform-team@yourcompany.com",
  "sre-team@yourcompany.com"
]
critical_alert_phones = [
  "+1-555-0911",  # On-call primary
  "+1-555-0912"   # On-call secondary
]

# Feature Flags - Full features for production
enable_diagnostic_logs   = true
enable_threat_detection  = true
enable_auto_scaling     = true
enable_geo_redundancy   = true
enable_disaster_recovery = true

# Data Retention - Compliance-driven retention
log_retention_days    = 90
backup_retention_days = 35
archive_after_days   = 365

# Performance - Optimized for production workloads
event_hub_throughput_units = 20
cosmos_db_max_throughput   = 20000
sql_pool_performance_level = "DW1000c"

# ML Configuration - Production-ready compute
ml_compute_min_nodes = 2
ml_compute_max_nodes = 10

# Security
enable_cmk_encryption   = true
security_contact_email  = "security-prod@yourcompany.com"
security_contact_phone  = "+1-555-0911"

# Compliance - Full compliance suite
compliance_standards = ["PCI-DSS", "ISO-27001", "HIPAA", "GDPR", "SOC2"]

# Budget - Production environment budget
monthly_budget_amount = 50000
budget_alert_thresholds = [80, 90, 100, 110]

# Disaster Recovery
rpo_minutes = 15  # 15-minute RPO for critical data
rto_minutes = 60  # 1-hour RTO for full recovery

tags = {
  Owner              = "Data Platform Team"
  Environment        = "Production"
  Purpose           = "Production Data Platform"
  DataClassification = "Confidential"
  BusinessCritical  = "true"
  DisasterRecovery  = "enabled"
  Compliance        = "PCI-DSS,HIPAA,GDPR"
  SLA               = "99.99"
  BackupPolicy      = "Daily"
  MaintenanceWindow = "Sunday 2-6 AM EST"
}