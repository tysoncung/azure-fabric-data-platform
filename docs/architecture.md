# Architecture Deep Dive

## Table of Contents
1. [Platform Architecture](#platform-architecture)
2. [Data Pipeline Architecture](#data-pipeline-architecture)
3. [Data Lake Design](#data-lake-design)
4. [Data Warehouse Structure](#data-warehouse-structure)
5. [API Layer Architecture](#api-layer-architecture)
6. [ML Platform Architecture](#ml-platform-architecture)
7. [Security Architecture](#security-architecture)
8. [Network Architecture](#network-architecture)

## Platform Architecture

### Core Components

#### Microsoft Fabric Workspace Organization
```
Production Workspace
├── Fraud Detection Domain
│   ├── Real-time Analytics (KQL Database)
│   ├── Lakehouse (Transaction Data)
│   ├── ML Models
│   └── Power BI Reports
├── IoT Predictive Maintenance Domain
│   ├── Real-time Analytics (Sensor Data)
│   ├── Lakehouse (Equipment Data)
│   ├── Time Series Database
│   └── Maintenance Dashboards
└── Customer Analytics Domain
    ├── Data Warehouse
    ├── Lakehouse (Customer Data)
    ├── ML Models
    └── Analytics Reports
```

### Technology Decisions

| Component | Technology Choice | Rationale |
|-----------|------------------|-----------|
| **Streaming Platform** | Event Hubs + IoT Hub | High throughput, low latency, native Azure integration |
| **Real-time Processing** | Fabric Real-Time Analytics (KQL) | Sub-second query performance, time-series optimized |
| **Batch Processing** | Fabric Data Engineering (Spark) | Scalable, supports Python/Scala/SQL |
| **Data Warehouse** | Fabric Data Warehouse | Integrated with OneLake, no data movement |
| **ML Platform** | Fabric Data Science + Azure ML | Integrated notebooks, MLflow support, production deployment |
| **API Layer** | Azure API Management + Functions | Scalable, serverless, built-in security |
| **Orchestration** | Data Factory in Fabric | Native integration, visual pipeline designer |

## Data Pipeline Architecture

### Ingestion Patterns

#### Pattern 1: Real-time Transaction Ingestion
```python
# Event Hub Configuration
transaction_event_hub:
  name: "txn-events-hub"
  partitions: 32  # High partition count for parallelism
  retention_days: 7
  throughput_units: 20  # Auto-scale enabled
  capture:
    enabled: true
    destination: "onelake/bronze/transactions/raw"
    format: "avro"
    interval_seconds: 300
    size_mb: 314572800  # 300MB
```

#### Pattern 2: IoT Sensor Streaming
```python
# IoT Hub Configuration  
iot_hub:
  name: "manufacturing-iot-hub"
  sku: "S3"  # Standard tier, high volume
  units: 10
  partitions: 32
  device_provisioning: true
  routes:
    - name: "sensor-telemetry"
      source: "DeviceMessages"
      endpoint: "onelake/bronze/iot/telemetry"
    - name: "sensor-alerts"
      source: "DeviceMessages"
      condition: "anomaly_score > 0.8"
      endpoint: "event-hub-alerts"
```

#### Pattern 3: Batch Data Ingestion
```python
# Data Factory Pipeline Configuration
batch_pipeline:
  name: "customer-data-pipeline"
  triggers:
    - type: "schedule"
      recurrence: "0 2 * * *"  # Daily at 2 AM
  activities:
    - type: "copy"
      source:
        type: "SqlServer"
        query: "SELECT * FROM sales WHERE date >= @{pipeline().parameters.windowStart}"
      sink:
        type: "OneLake"
        path: "bronze/sales/daily"
        format: "delta"
```

### Transformation Architecture

#### Medallion Architecture Implementation

```python
# Bronze → Silver Transformation
silver_transformation:
  source: "bronze/transactions"
  target: "silver/transactions"
  operations:
    - data_quality_checks:
        - null_checks: ["transaction_id", "amount", "timestamp"]
        - range_checks: 
            amount: [0.01, 1000000]
        - format_validation:
            credit_card: "PAN_regex"
    - deduplication:
        keys: ["transaction_id"]
        strategy: "keep_latest"
    - standardization:
        - timestamp_format: "ISO8601"
        - currency_conversion: "USD"
    - pii_masking:
        - credit_card: "tokenization"
        - customer_email: "hash"

# Silver → Gold Transformation  
gold_transformation:
  source: "silver/transactions"
  target: "gold/fraud_features"
  operations:
    - feature_engineering:
        - velocity_features:
            - txn_count_1min
            - txn_count_5min
            - txn_count_1hour
        - amount_features:
            - amount_zscore
            - amount_percentile
        - merchant_features:
            - merchant_risk_score
            - merchant_category_risk
    - aggregations:
        - daily_summaries
        - hourly_patterns
        - merchant_profiles
```

## Data Lake Design

### OneLake Organization Structure

```
OneLake/
├── bronze/                 # Raw data landing zone
│   ├── transactions/      # Partitioned by date/hour
│   │   └── year=2024/month=01/day=15/hour=14/
│   ├── iot/              # Partitioned by device/date
│   │   └── device_id=sensor001/date=2024-01-15/
│   └── customer/         # Partitioned by source/date
│       └── source=crm/date=2024-01-15/
├── silver/               # Cleansed and standardized
│   ├── transactions/     # Delta format, SCD Type 2
│   ├── iot_telemetry/   # Time-series optimized
│   └── customer_360/     # Unified customer view
├── gold/                 # Business-ready datasets
│   ├── fraud_detection/
│   │   ├── features/    # ML-ready features
│   │   └── scores/      # Real-time scoring results
│   ├── predictive_maintenance/
│   │   ├── equipment_health/
│   │   └── failure_predictions/
│   └── customer_analytics/
│       ├── segmentation/
│       └── ltv_models/
└── sandbox/             # Data science experimentation
```

### Storage Optimization Strategies

```yaml
storage_configuration:
  bronze:
    format: "avro/json"  # Original format preservation
    compression: "snappy"
    retention: "90 days"
    lifecycle:
      - age: 30
        action: "cool"
      - age: 90
        action: "archive"
  
  silver:
    format: "delta"
    compression: "zstd"
    optimization:
      - auto_optimize: true
      - vacuum_retention: 168  # 7 days
      - z_order_columns: ["transaction_date", "customer_id"]
    retention: "2 years"
  
  gold:
    format: "delta"
    compression: "zstd"
    caching: "enabled"
    materialized_views: true
    retention: "7 years"
```

## Data Warehouse Structure

### Dimensional Model Design

```sql
-- Fact Tables
CREATE TABLE fact_transactions (
    transaction_key BIGINT IDENTITY(1,1),
    transaction_id VARCHAR(100) NOT NULL,
    date_key INT NOT NULL,
    time_key INT NOT NULL,
    customer_key INT NOT NULL,
    merchant_key INT NOT NULL,
    amount DECIMAL(18,2) NOT NULL,
    fraud_score DECIMAL(5,4),
    is_fraudulent BIT,
    processing_time_ms INT,
    created_timestamp DATETIME2,
    INDEX idx_date_customer (date_key, customer_key),
    INDEX idx_fraud_score (fraud_score) WHERE fraud_score > 0.7
) WITH (DISTRIBUTION = HASH(customer_key), PARTITION (date_key RANGE RIGHT FOR VALUES()));

CREATE TABLE fact_iot_readings (
    reading_key BIGINT IDENTITY(1,1),
    device_key INT NOT NULL,
    timestamp_key BIGINT NOT NULL,
    temperature DECIMAL(5,2),
    pressure DECIMAL(7,2),
    vibration DECIMAL(5,2),
    anomaly_score DECIMAL(5,4),
    predicted_failure_hours INT,
    INDEX idx_device_time (device_key, timestamp_key),
    INDEX idx_anomaly (anomaly_score) WHERE anomaly_score > 0.5
) WITH (DISTRIBUTION = HASH(device_key), PARTITION (timestamp_key RANGE RIGHT FOR VALUES()));

-- Dimension Tables
CREATE TABLE dim_customer (
    customer_key INT IDENTITY(1,1),
    customer_id VARCHAR(100) NOT NULL,
    customer_segment VARCHAR(50),
    lifetime_value DECIMAL(12,2),
    risk_category VARCHAR(20),
    registration_date DATE,
    last_activity_date DATE,
    is_current BIT,
    valid_from DATETIME2,
    valid_to DATETIME2,
    INDEX idx_customer_id (customer_id)
) WITH (DISTRIBUTION = REPLICATE);

CREATE TABLE dim_device (
    device_key INT IDENTITY(1,1),
    device_id VARCHAR(100) NOT NULL,
    device_type VARCHAR(50),
    manufacturer VARCHAR(100),
    model VARCHAR(100),
    installation_date DATE,
    location VARCHAR(200),
    maintenance_schedule VARCHAR(50),
    is_active BIT,
    INDEX idx_device_id (device_id)
) WITH (DISTRIBUTION = REPLICATE);
```

### Real-time Views for Operational Analytics

```sql
-- Real-time Fraud Monitoring View
CREATE MATERIALIZED VIEW vw_realtime_fraud_monitoring AS
SELECT 
    t.transaction_id,
    t.amount,
    t.fraud_score,
    c.risk_category,
    m.merchant_risk_level,
    CASE 
        WHEN t.fraud_score > 0.9 THEN 'BLOCK'
        WHEN t.fraud_score > 0.7 THEN 'REVIEW'
        ELSE 'APPROVE'
    END as action,
    t.created_timestamp
FROM fact_transactions t
JOIN dim_customer c ON t.customer_key = c.customer_key
JOIN dim_merchant m ON t.merchant_key = m.merchant_key
WHERE t.created_timestamp >= DATEADD(MINUTE, -5, GETUTCDATE())
WITH (DISTRIBUTION = HASH(transaction_id));

-- Equipment Health Monitoring View
CREATE MATERIALIZED VIEW vw_equipment_health AS
SELECT 
    d.device_id,
    d.device_type,
    d.location,
    AVG(i.temperature) as avg_temp_5min,
    AVG(i.vibration) as avg_vibration_5min,
    MAX(i.anomaly_score) as max_anomaly_5min,
    MIN(i.predicted_failure_hours) as min_failure_hours,
    CASE
        WHEN MIN(i.predicted_failure_hours) < 24 THEN 'CRITICAL'
        WHEN MIN(i.predicted_failure_hours) < 168 THEN 'WARNING'
        ELSE 'NORMAL'
    END as maintenance_priority
FROM fact_iot_readings i
JOIN dim_device d ON i.device_key = d.device_key
WHERE i.timestamp_key >= DATEADD(MINUTE, -5, GETUTCDATE())
GROUP BY d.device_id, d.device_type, d.location
WITH (DISTRIBUTION = HASH(device_id));
```

## API Layer Architecture

### API Gateway Configuration

```yaml
api_management:
  name: "fabric-data-platform-api"
  sku: "Premium"  # For VNet integration
  capacity: 2
  virtual_network:
    mode: "Internal"
    subnet: "api-subnet"
  
  apis:
    - name: "fraud-detection-api"
      path: "/fraud/v1"
      backend: "https://fraud-scoring-function.azurewebsites.net"
      policies:
        - rate_limit: "1000 per minute per key"
        - cache: "60 seconds for GET"
        - authentication: "OAuth2.0"
      operations:
        - name: "score-transaction"
          method: "POST"
          path: "/score"
          response_time_sla: "100ms"
    
    - name: "iot-monitoring-api"
      path: "/iot/v1"
      backend: "https://iot-analytics-function.azurewebsites.net"
      policies:
        - rate_limit: "5000 per minute"
        - compression: "gzip"
      operations:
        - name: "get-device-health"
          method: "GET"
          path: "/device/{deviceId}/health"
        - name: "get-predictions"
          method: "GET"
          path: "/device/{deviceId}/predictions"
    
    - name: "customer-insights-api"
      path: "/customer/v1"
      backend: "https://customer-analytics.azurewebsites.net"
      policies:
        - caching: "300 seconds"
        - transformation: "JSON to XML available"
```

### Function Apps for API Backend

```python
# Fraud Scoring Function
import azure.functions as func
import pandas as pd
from azure.cosmos import CosmosClient
import joblib
import json

async def score_transaction(req: func.HttpRequest) -> func.HttpResponse:
    try:
        # Parse request
        transaction = req.get_json()
        
        # Load model from cache or blob storage
        model = await load_model('fraud_detection_model_v2')
        
        # Feature engineering
        features = engineer_features(transaction)
        
        # Score transaction
        fraud_score = model.predict_proba(features)[0][1]
        
        # Check velocity rules
        velocity_check = await check_velocity_rules(
            transaction['customer_id'],
            transaction['amount']
        )
        
        # Combine ML score with rules
        final_score = combine_scores(fraud_score, velocity_check)
        
        # Log to Cosmos DB for audit
        await log_scoring_decision(transaction, final_score)
        
        # Return response
        response = {
            'transaction_id': transaction['id'],
            'fraud_score': float(final_score),
            'action': 'BLOCK' if final_score > 0.9 else 'APPROVE',
            'response_time_ms': 45
        }
        
        return func.HttpResponse(
            json.dumps(response),
            status_code=200,
            headers={'Content-Type': 'application/json'}
        )
    except Exception as e:
        logging.error(f"Scoring error: {str(e)}")
        return func.HttpResponse(status_code=500)
```

## ML Platform Architecture

### ML Pipeline Structure

```python
# MLOps Pipeline Configuration
ml_pipelines:
  fraud_detection:
    training:
      trigger: "daily"
      steps:
        - data_preparation:
            source: "gold/fraud_features"
            validation: "great_expectations"
            split: [0.7, 0.15, 0.15]  # train/val/test
        - feature_engineering:
            transformations: "sklearn_pipeline"
            feature_store: "feast"
        - model_training:
            algorithms: ["xgboost", "lightgbm", "neural_network"]
            hyperparameter_tuning: "optuna"
            cross_validation: 5
        - model_evaluation:
            metrics: ["auc", "precision@0.95recall", "f1"]
            threshold_optimization: true
        - model_registration:
            registry: "mlflow"
            tags: ["production_candidate"]
    
    deployment:
      strategy: "blue_green"
      endpoints:
        - name: "fraud-scoring-realtime"
          compute: "gpu_cluster"
          instances: 3
          autoscale:
            min: 2
            max: 10
            metric: "latency"
      monitoring:
        - data_drift: "evidently"
        - model_performance: "custom_metrics"
        - alerting: "azure_monitor"

  predictive_maintenance:
    training:
      trigger: "weekly"
      steps:
        - time_series_preprocessing:
            window_size: 168  # hours
            lag_features: [1, 24, 168]
        - anomaly_detection:
            algorithms: ["isolation_forest", "lstm_autoencoder"]
        - remaining_life_estimation:
            algorithms: ["random_forest_regressor", "gradient_boosting"]
        - ensemble:
            method: "weighted_average"
            optimization: "bayesian"

  customer_segmentation:
    training:
      trigger: "monthly"
      steps:
        - feature_extraction:
            behavioral: true
            transactional: true
            demographic: true
        - clustering:
            algorithms: ["kmeans", "dbscan", "hierarchical"]
            optimal_clusters: "elbow_method"
        - classification:
            algorithm: "random_forest"
            predict: "segment_membership"
```

### Model Serving Architecture

```yaml
model_endpoints:
  fraud_detection:
    type: "real-time"
    deployment:
      compute_type: "gpu"
      instance_type: "Standard_NC6s_v3"
      replica_count: 3
    performance:
      target_latency: "50ms"
      target_throughput: "10000 req/sec"
    features:
      - a_b_testing: true
      - shadow_mode: true
      - canary_deployment: true
    
  predictive_maintenance:
    type: "batch"
    deployment:
      compute_type: "cpu"
      instance_type: "Standard_D4s_v3"
      schedule: "*/15 * * * *"  # Every 15 minutes
    
  customer_analytics:
    type: "streaming"
    deployment:
      compute_type: "spark_streaming"
      cluster_size: 5
      processing_time: "1 minute"
```

## Security Architecture

### Defense in Depth Strategy

```yaml
security_layers:
  network:
    - private_endpoints: "all_services"
    - nsg_rules: "least_privilege"
    - ddos_protection: "standard"
    - waf: "enabled_with_custom_rules"
  
  identity:
    - authentication: "azure_ad"
    - mfa: "required_for_all"
    - conditional_access: "location_and_device"
    - privileged_identity_management: "enabled"
  
  data:
    - encryption_at_rest: "customer_managed_keys"
    - encryption_in_transit: "tls_1.3"
    - data_masking: "dynamic"
    - row_level_security: "enabled"
  
  application:
    - api_authentication: "oauth2_with_scopes"
    - rate_limiting: "per_client"
    - input_validation: "strict"
    - output_encoding: "context_aware"
  
  monitoring:
    - siem: "azure_sentinel"
    - threat_detection: "azure_defender"
    - audit_logging: "comprehensive"
    - compliance_scanning: "continuous"
```

### PCI DSS Compliance for Transaction Data

```yaml
pci_dss_controls:
  network_segmentation:
    - cardholder_data_environment: "isolated_vnet"
    - dmz: "implemented"
    - firewall_rules: "documented_and_reviewed"
  
  access_control:
    - need_to_know: "enforced"
    - unique_ids: "per_user"
    - password_policy: "complex_90_days"
    - inactive_session_timeout: "15_minutes"
  
  data_protection:
    - pan_masking: "show_first6_last4"
    - pan_storage: "tokenized"
    - encryption: "aes_256"
    - key_management: "hsm_backed"
  
  monitoring:
    - file_integrity_monitoring: "enabled"
    - log_retention: "1_year"
    - daily_review: "automated_with_alerts"
    - intrusion_detection: "real_time"
```

## Network Architecture

### Hub-Spoke Topology

```yaml
network_topology:
  hub_vnet:
    name: "hub-vnet"
    address_space: "10.0.0.0/16"
    subnets:
      - name: "firewall-subnet"
        prefix: "10.0.1.0/24"
      - name: "gateway-subnet"
        prefix: "10.0.2.0/24"
      - name: "management-subnet"
        prefix: "10.0.3.0/24"
  
  spoke_vnets:
    - name: "fabric-vnet"
      address_space: "10.1.0.0/16"
      subnets:
        - name: "compute-subnet"
          prefix: "10.1.1.0/24"
        - name: "storage-subnet"
          prefix: "10.1.2.0/24"
        - name: "private-endpoint-subnet"
          prefix: "10.1.3.0/24"
    
    - name: "ml-vnet"
      address_space: "10.2.0.0/16"
      subnets:
        - name: "training-subnet"
          prefix: "10.2.1.0/24"
        - name: "inference-subnet"
          prefix: "10.2.2.0/24"
  
  connectivity:
    - peering: "hub_to_all_spokes"
    - express_route: "primary_and_backup"
    - vpn: "s2s_backup"
    - bastion: "hub_management"
```

## Disaster Recovery Architecture

```yaml
disaster_recovery:
  rpo_targets:
    fraud_detection: "1 minute"
    iot_monitoring: "5 minutes"
    customer_analytics: "1 hour"
  
  rto_targets:
    fraud_detection: "5 minutes"
    iot_monitoring: "15 minutes"
    customer_analytics: "4 hours"
  
  backup_strategy:
    onelake:
      - geo_replication: "enabled"
      - backup_region: "paired_region"
      - point_in_time_restore: "35_days"
    
    databases:
      - automated_backup: "every_4_hours"
      - retention: "35_days"
      - geo_redundant: true
    
    ml_models:
      - model_registry: "replicated"
      - artifact_store: "geo_redundant"
  
  failover_procedures:
    - automatic: ["fraud_detection", "iot_monitoring"]
    - manual: ["customer_analytics"]
    - testing_frequency: "quarterly"
```