# Variables for Azure Fabric Data Platform

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus2"
}

variable "secondary_location" {
  description = "Secondary Azure region for disaster recovery"
  type        = string
  default     = "westus2"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "fabric-platform"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

# Networking Variables
variable "hub_vnet_address_space" {
  description = "Address space for hub VNet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "spoke_vnet_address_space" {
  description = "Address space for spoke VNets"
  type        = map(list(string))
  default = {
    fabric   = ["10.1.0.0/16"]
    ml       = ["10.2.0.0/16"]
    data     = ["10.3.0.0/16"]
  }
}

variable "enable_bastion" {
  description = "Enable Azure Bastion for secure RDP/SSH"
  type        = bool
  default     = true
}

variable "allowed_ip_ranges" {
  description = "Allowed IP ranges for public endpoints"
  type        = list(string)
  default     = []
}

# Microsoft Fabric Variables
variable "fabric_capacity_sku" {
  description = "Microsoft Fabric capacity SKU"
  type        = string
  default     = "F64"
  validation {
    condition     = contains(["F2", "F4", "F8", "F16", "F32", "F64", "F128", "F256", "F512", "F1024", "F2048"], var.fabric_capacity_sku)
    error_message = "Invalid Fabric capacity SKU."
  }
}

variable "fabric_admin_users" {
  description = "List of admin users for Fabric workspaces"
  type        = list(string)
}

# API Management Variables
variable "api_publisher_email" {
  description = "Email for API Management publisher"
  type        = string
}

variable "api_publisher_name" {
  description = "Name for API Management publisher"
  type        = string
}

# Alert Configuration
variable "critical_alert_emails" {
  description = "Email addresses for critical alerts"
  type        = list(string)
}

variable "critical_alert_phones" {
  description = "Phone numbers for critical alerts (SMS)"
  type        = list(string)
  default     = []
}

variable "warning_alert_emails" {
  description = "Email addresses for warning alerts"
  type        = list(string)
}

# Location Abbreviations
variable "location_abbreviations" {
  description = "Mapping of Azure regions to abbreviations"
  type        = map(string)
  default = {
    eastus         = "eus"
    eastus2        = "eus2"
    westus         = "wus"
    westus2        = "wus2"
    centralus      = "cus"
    northeurope    = "neu"
    westeurope     = "weu"
    southeastasia  = "sea"
    australiaeast  = "aue"
  }
}

# Feature Flags
variable "enable_private_endpoints" {
  description = "Enable private endpoints for all services"
  type        = bool
  default     = true
}

variable "enable_diagnostic_logs" {
  description = "Enable diagnostic logs for all services"
  type        = bool
  default     = true
}

variable "enable_threat_detection" {
  description = "Enable advanced threat detection"
  type        = bool
  default     = true
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for applicable services"
  type        = bool
  default     = true
}

variable "enable_geo_redundancy" {
  description = "Enable geo-redundancy for storage and databases"
  type        = bool
  default     = false
}

# Data Retention Policies
variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 90
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 35
}

variable "archive_after_days" {
  description = "Number of days before archiving cold data"
  type        = number
  default     = 180
}

# Performance Tuning
variable "event_hub_throughput_units" {
  description = "Throughput units for Event Hub namespace"
  type        = number
  default     = 20
}

variable "cosmos_db_max_throughput" {
  description = "Maximum RU/s for Cosmos DB autoscale"
  type        = number
  default     = 20000
}

variable "sql_pool_performance_level" {
  description = "Performance level for Synapse SQL pool"
  type        = string
  default     = "DW1000c"
}

# ML Configuration
variable "ml_compute_min_nodes" {
  description = "Minimum nodes for ML compute clusters"
  type        = number
  default     = 0
}

variable "ml_compute_max_nodes" {
  description = "Maximum nodes for ML compute clusters"
  type        = number
  default     = 10
}

variable "ml_model_registry_name" {
  description = "Name for ML model registry"
  type        = string
  default     = "ml-model-registry"
}

# Security Configuration
variable "enable_cmk_encryption" {
  description = "Enable customer-managed key encryption"
  type        = bool
  default     = true
}

variable "security_contact_email" {
  description = "Security contact email for Azure Security Center"
  type        = string
}

variable "security_contact_phone" {
  description = "Security contact phone for Azure Security Center"
  type        = string
}

# Compliance Configuration
variable "compliance_standards" {
  description = "List of compliance standards to enable"
  type        = list(string)
  default     = ["PCI-DSS", "ISO-27001", "HIPAA", "GDPR"]
}

variable "data_classification_labels" {
  description = "Data classification labels to apply"
  type        = list(string)
  default     = ["Public", "Internal", "Confidential", "Restricted"]
}

# Budget Configuration
variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
}

variable "budget_alert_thresholds" {
  description = "Budget alert thresholds as percentages"
  type        = list(number)
  default     = [80, 90, 100, 110]
}

# Disaster Recovery Configuration
variable "enable_disaster_recovery" {
  description = "Enable disaster recovery configuration"
  type        = bool
  default     = false
}

variable "rpo_minutes" {
  description = "Recovery Point Objective in minutes"
  type        = number
  default     = 60
}

variable "rto_minutes" {
  description = "Recovery Time Objective in minutes"
  type        = number
  default     = 240
}