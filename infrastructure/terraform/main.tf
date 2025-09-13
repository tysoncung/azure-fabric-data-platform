# Main Terraform configuration for Azure Fabric Data Platform

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.43.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }
  }
  
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstateplatform"
    container_name      = "tfstate"
    key                 = "fabric-platform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

# Local variables
locals {
  common_tags = merge(
    var.tags,
    {
      Environment     = var.environment
      Project        = "FabricDataPlatform"
      ManagedBy      = "Terraform"
      LastModified   = timestamp()
      CostCenter     = var.cost_center
      DataClassification = "Confidential"
    }
  )
  
  resource_prefix = "${var.project_name}-${var.environment}"
  location_short  = var.location_abbreviations[var.location]
}

# Resource Groups
module "resource_groups" {
  source = "./modules/resource-groups"
  
  environment     = var.environment
  location        = var.location
  resource_prefix = local.resource_prefix
  tags           = local.common_tags
}

# Networking
module "networking" {
  source = "./modules/networking"
  
  environment          = var.environment
  location            = var.location
  resource_prefix     = local.resource_prefix
  resource_group_name = module.resource_groups.networking_rg_name
  
  hub_vnet_address_space   = var.hub_vnet_address_space
  spoke_vnet_address_space = var.spoke_vnet_address_space
  enable_ddos_protection   = var.environment == "prod" ? true : false
  enable_bastion          = var.enable_bastion
  
  tags = local.common_tags
}

# Security & Identity
module "security" {
  source = "./modules/security"
  
  environment          = var.environment
  location            = var.location
  resource_prefix     = local.resource_prefix
  resource_group_name = module.resource_groups.security_rg_name
  
  key_vault_sku                = var.environment == "prod" ? "premium" : "standard"
  enable_purge_protection      = var.environment == "prod" ? true : false
  enable_rbac_authorization    = true
  network_acls_default_action  = "Deny"
  allowed_ip_ranges           = var.allowed_ip_ranges
  
  tags = local.common_tags
}

# Microsoft Fabric Workspace
module "fabric" {
  source = "./modules/fabric"
  
  environment          = var.environment
  location            = var.location
  resource_prefix     = local.resource_prefix
  resource_group_name = module.resource_groups.fabric_rg_name
  
  fabric_capacity_sku = var.fabric_capacity_sku
  admin_users        = var.fabric_admin_users
  
  workspace_configuration = {
    fraud_detection = {
      name        = "${local.resource_prefix}-fraud-ws"
      description = "Fraud Detection Domain Workspace"
      features = [
        "lakehouse",
        "data_warehouse",
        "real_time_analytics",
        "data_science"
      ]
    }
    iot_maintenance = {
      name        = "${local.resource_prefix}-iot-ws"
      description = "IoT Predictive Maintenance Workspace"
      features = [
        "lakehouse",
        "real_time_analytics",
        "data_science"
      ]
    }
    customer_analytics = {
      name        = "${local.resource_prefix}-customer-ws"
      description = "Customer Analytics Workspace"
      features = [
        "lakehouse",
        "data_warehouse",
        "data_science"
      ]
    }
  }
  
  tags = local.common_tags
}

# Event Streaming Infrastructure
module "event_streaming" {
  source = "./modules/event-streaming"
  
  environment          = var.environment
  location            = var.location
  resource_prefix     = local.resource_prefix
  resource_group_name = module.resource_groups.streaming_rg_name
  subnet_id           = module.networking.streaming_subnet_id
  
  # Event Hub Configuration
  event_hub_namespace_sku = var.environment == "prod" ? "Premium" : "Standard"
  event_hub_capacity      = var.environment == "prod" ? 4 : 1
  
  event_hubs = {
    transactions = {
      partition_count   = 32
      message_retention = 7
      capture_enabled   = true
      capture_interval  = 300
    }
    fraud_alerts = {
      partition_count   = 8
      message_retention = 1
      capture_enabled   = false
    }
  }
  
  # IoT Hub Configuration
  iot_hub_sku  = var.environment == "prod" ? "S3" : "S1"
  iot_hub_units = var.environment == "prod" ? 10 : 1
  
  iot_hub_routes = [
    {
      name            = "telemetry"
      source          = "DeviceMessages"
      endpoint_type   = "eventhub"
      endpoint_name   = "telemetry-endpoint"
    },
    {
      name            = "alerts"
      source          = "DeviceMessages"
      condition       = "anomaly_score > 0.8"
      endpoint_type   = "eventhub"
      endpoint_name   = "alert-endpoint"
    }
  ]
  
  tags = local.common_tags
}

# Storage Layer (OneLake Backend)
module "storage" {
  source = "./modules/storage"
  
  environment          = var.environment
  location            = var.location
  resource_prefix     = local.resource_prefix
  resource_group_name = module.resource_groups.storage_rg_name
  subnet_id           = module.networking.storage_subnet_id
  
  storage_account_tier             = "Standard"
  storage_account_replication_type = var.environment == "prod" ? "GZRS" : "LRS"
  enable_hns                      = true  # Hierarchical namespace for ADLS Gen2
  enable_sftp                     = false
  
  containers = {
    bronze = {
      access_type = "private"
    }
    silver = {
      access_type = "private"
    }
    gold = {
      access_type = "private"
    }
    ml_artifacts = {
      access_type = "private"
    }
  }
  
  lifecycle_rules = [
    {
      name    = "archive-old-bronze"
      enabled = true
      prefix  = "bronze/"
      
      delete_after_days       = 90
      cool_after_days        = 30
      archive_after_days     = 60
    },
    {
      name    = "optimize-silver"
      enabled = true
      prefix  = "silver/"
      
      cool_after_days    = 180
      archive_after_days = 365
    }
  ]
  
  tags = local.common_tags
}

# Azure Machine Learning
module "machine_learning" {
  source = "./modules/machine-learning"
  
  environment          = var.environment
  location            = var.location
  resource_prefix     = local.resource_prefix
  resource_group_name = module.resource_groups.ml_rg_name
  
  workspace_sku                = var.environment == "prod" ? "Enterprise" : "Basic"
  storage_account_id          = module.storage.storage_account_id
  key_vault_id               = module.security.key_vault_id
  application_insights_id     = module.monitoring.application_insights_id
  container_registry_id      = module.container_registry.acr_id
  
  compute_clusters = {
    cpu_cluster = {
      vm_size            = "Standard_DS3_v2"
      min_nodes          = var.environment == "prod" ? 2 : 0
      max_nodes          = var.environment == "prod" ? 10 : 4
      idle_seconds       = 1800
      scale_down_enabled = true
    }
    gpu_cluster = {
      vm_size            = "Standard_NC6s_v3"
      min_nodes          = 0
      max_nodes          = var.environment == "prod" ? 4 : 2
      idle_seconds       = 1800
      scale_down_enabled = true
    }
  }
  
  tags = local.common_tags
}

# API Management
module "api_management" {
  source = "./modules/api-management"
  
  environment          = var.environment
  location            = var.location
  resource_prefix     = local.resource_prefix
  resource_group_name = module.resource_groups.api_rg_name
  subnet_id           = module.networking.api_subnet_id
  
  sku_name     = var.environment == "prod" ? "Premium" : "Developer"
  sku_capacity = var.environment == "prod" ? 2 : 1
  
  publisher_email = var.api_publisher_email
  publisher_name  = var.api_publisher_name
  
  apis = {
    fraud_detection = {
      path         = "fraud/v1"
      display_name = "Fraud Detection API"
      protocols    = ["https"]
    }
    iot_monitoring = {
      path         = "iot/v1"
      display_name = "IoT Monitoring API"
      protocols    = ["https"]
    }
    customer_insights = {
      path         = "customer/v1"
      display_name = "Customer Insights API"
      protocols    = ["https"]
    }
  }
  
  products = {
    internal = {
      display_name        = "Internal APIs"
      subscription_required = true
      approval_required    = true
      published           = true
    }
    partner = {
      display_name        = "Partner APIs"
      subscription_required = true
      approval_required    = true
      published           = true
      subscriptions_limit  = 10
    }
  }
  
  tags = local.common_tags
}

# Function Apps for API Backend
module "function_apps" {
  source = "./modules/function-apps"
  
  environment          = var.environment
  location            = var.location
  resource_prefix     = local.resource_prefix
  resource_group_name = module.resource_groups.compute_rg_name
  subnet_id           = module.networking.function_subnet_id
  
  storage_account_id     = module.storage.storage_account_id
  application_insights_id = module.monitoring.application_insights_id
  
  function_apps = {
    fraud_scoring = {
      name              = "${local.resource_prefix}-fraud-func"
      service_plan_sku  = var.environment == "prod" ? "EP2" : "Y1"
      runtime_version   = "4"
      runtime_stack     = "python"
      python_version    = "3.10"
      
      app_settings = {
        "FRAUD_MODEL_VERSION"     = "v2.3"
        "COSMOS_DB_ENDPOINT"      = module.cosmos_db.endpoint
        "EVENT_HUB_CONNECTION"    = module.event_streaming.fraud_alerts_connection_string
        "ML_ENDPOINT"            = module.machine_learning.fraud_endpoint_url
      }
    }
    iot_analytics = {
      name              = "${local.resource_prefix}-iot-func"
      service_plan_sku  = var.environment == "prod" ? "EP2" : "Y1"
      runtime_version   = "4"
      runtime_stack     = "python"
      python_version    = "3.10"
      
      app_settings = {
        "IOT_HUB_CONNECTION"     = module.event_streaming.iot_hub_connection_string
        "TIME_SERIES_DB"        = module.cosmos_db.endpoint
        "ML_ENDPOINT"           = module.machine_learning.maintenance_endpoint_url
      }
    }
  }
  
  tags = local.common_tags
}

# Monitoring & Observability
module "monitoring" {
  source = "./modules/monitoring"
  
  environment          = var.environment
  location            = var.location
  resource_prefix     = local.resource_prefix
  resource_group_name = module.resource_groups.monitoring_rg_name
  
  log_analytics_sku           = "PerGB2018"
  log_analytics_retention_days = var.environment == "prod" ? 90 : 30
  
  application_insights_type = "web"
  
  action_groups = {
    critical = {
      short_name = "critical"
      email_receivers = var.critical_alert_emails
      sms_receivers   = var.environment == "prod" ? var.critical_alert_phones : []
    }
    warning = {
      short_name = "warning"
      email_receivers = var.warning_alert_emails
    }
  }
  
  metric_alerts = {
    high_fraud_rate = {
      description = "Fraud rate exceeds threshold"
      severity    = 1
      frequency   = "PT1M"
      window_size = "PT5M"
      criteria = {
        metric_name = "fraud_rate"
        aggregation = "Average"
        operator    = "GreaterThan"
        threshold   = 0.05
      }
    }
    iot_device_failure = {
      description = "IoT device failure prediction"
      severity    = 2
      frequency   = "PT5M"
      window_size = "PT15M"
      criteria = {
        metric_name = "predicted_failure_hours"
        aggregation = "Minimum"
        operator    = "LessThan"
        threshold   = 24
      }
    }
  }
  
  tags = local.common_tags
}

# Data Governance (Microsoft Purview)
module "purview" {
  source = "./modules/purview"
  
  environment          = var.environment
  location            = var.location
  resource_prefix     = local.resource_prefix
  resource_group_name = module.resource_groups.governance_rg_name
  
  purview_account_name = "${local.resource_prefix}-purview"
  
  managed_resources = {
    event_hub_namespace_id = module.event_streaming.namespace_id
    storage_account_id     = module.storage.storage_account_id
  }
  
  collections = [
    {
      name        = "fraud-detection"
      description = "Fraud detection data assets"
    },
    {
      name        = "iot-maintenance"
      description = "IoT and maintenance data assets"
    },
    {
      name        = "customer-analytics"
      description = "Customer analytics data assets"
    }
  ]
  
  tags = local.common_tags
}

# Container Registry
module "container_registry" {
  source = "./modules/container-registry"
  
  environment          = var.environment
  location            = var.location
  resource_prefix     = local.resource_prefix
  resource_group_name = module.resource_groups.container_rg_name
  
  sku                      = var.environment == "prod" ? "Premium" : "Standard"
  admin_enabled           = false
  public_network_access   = false
  zone_redundancy_enabled = var.environment == "prod" ? true : false
  
  georeplications = var.environment == "prod" ? [
    {
      location                = "westus2"
      zone_redundancy_enabled = true
    }
  ] : []
  
  tags = local.common_tags
}

# Cosmos DB for operational data
module "cosmos_db" {
  source = "./modules/cosmos-db"
  
  environment          = var.environment
  location            = var.location
  resource_prefix     = local.resource_prefix
  resource_group_name = module.resource_groups.database_rg_name
  
  offer_type                   = "Standard"
  consistency_level            = "Session"
  automatic_failover_enabled   = var.environment == "prod" ? true : false
  zone_redundancy_enabled      = var.environment == "prod" ? true : false
  
  geo_locations = var.environment == "prod" ? [
    {
      location          = var.location
      failover_priority = 0
    },
    {
      location          = var.secondary_location
      failover_priority = 1
    }
  ] : [
    {
      location          = var.location
      failover_priority = 0
    }
  ]
  
  databases = {
    fraud_detection = {
      throughput = 4000
      containers = {
        transactions = {
          partition_key = "/customerId"
          throughput    = 2000
        }
        fraud_scores = {
          partition_key = "/transactionId"
          throughput    = 1000
        }
      }
    }
    iot_telemetry = {
      throughput = 10000
      containers = {
        sensor_data = {
          partition_key = "/deviceId"
          throughput    = 5000
        }
        maintenance_predictions = {
          partition_key = "/equipmentId"
          throughput    = 2000
        }
      }
    }
  }
  
  tags = local.common_tags
}

# Outputs
output "fabric_workspace_urls" {
  value = module.fabric.workspace_urls
  description = "URLs for Microsoft Fabric workspaces"
}

output "api_gateway_url" {
  value = module.api_management.gateway_url
  description = "API Management gateway URL"
}

output "ml_workspace_url" {
  value = module.machine_learning.workspace_url
  description = "Azure Machine Learning workspace URL"
}

output "key_vault_uri" {
  value = module.security.key_vault_uri
  description = "Key Vault URI for secrets management"
}

output "storage_account_name" {
  value = module.storage.storage_account_name
  description = "Primary storage account name"
}