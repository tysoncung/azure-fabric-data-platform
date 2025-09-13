# Microsoft Fabric Module

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.43.0"
    }
  }
}

# Fabric Capacity
resource "azurerm_fabric_capacity" "main" {
  name                = "${var.resource_prefix}-fabric-capacity"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  sku {
    name = var.fabric_capacity_sku
    tier = "Fabric"
  }
  
  administration {
    members = var.admin_users
  }
  
  tags = var.tags
}

# Create Fabric Workspaces using REST API
resource "null_resource" "fabric_workspaces" {
  for_each = var.workspace_configuration
  
  provisioner "local-exec" {
    command = <<-EOT
      az rest --method POST \
        --uri "https://api.fabric.microsoft.com/v1/workspaces" \
        --headers "Content-Type=application/json" \
        --body '{
          "displayName": "${each.value.name}",
          "description": "${each.value.description}",
          "capacityId": "${azurerm_fabric_capacity.main.id}"
        }'
    EOT
  }
  
  depends_on = [azurerm_fabric_capacity.main]
}

# Lakehouse Configuration for Each Workspace
resource "null_resource" "fabric_lakehouses" {
  for_each = var.workspace_configuration
  
  provisioner "local-exec" {
    command = <<-EOT
      # Create Lakehouse
      az rest --method POST \
        --uri "https://api.fabric.microsoft.com/v1/workspaces/${each.key}/lakehouses" \
        --headers "Content-Type=application/json" \
        --body '{
          "displayName": "${each.value.name}-lakehouse",
          "description": "Lakehouse for ${each.value.description}"
        }'
      
      # Configure Delta Lake tables
      az rest --method POST \
        --uri "https://api.fabric.microsoft.com/v1/workspaces/${each.key}/lakehouses/tables" \
        --headers "Content-Type=application/json" \
        --body '{
          "tables": [
            {
              "name": "bronze_raw",
              "format": "delta",
              "partitionColumns": ["date", "hour"],
              "properties": {
                "delta.autoOptimize.optimizeWrite": "true",
                "delta.autoOptimize.autoCompact": "true"
              }
            },
            {
              "name": "silver_cleansed",
              "format": "delta",
              "partitionColumns": ["date"],
              "properties": {
                "delta.enableChangeDataFeed": "true"
              }
            },
            {
              "name": "gold_aggregated",
              "format": "delta",
              "properties": {
                "delta.dataSkippingNumIndexedCols": "32"
              }
            }
          ]
        }'
    EOT
  }
  
  depends_on = [null_resource.fabric_workspaces]
}

# KQL Database for Real-time Analytics
resource "null_resource" "fabric_kql_databases" {
  for_each = {
    for k, v in var.workspace_configuration : k => v
    if contains(v.features, "real_time_analytics")
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      # Create KQL Database
      az rest --method POST \
        --uri "https://api.fabric.microsoft.com/v1/workspaces/${each.key}/kqldatabases" \
        --headers "Content-Type=application/json" \
        --body '{
          "displayName": "${each.value.name}-realtime",
          "description": "Real-time analytics for ${each.value.description}",
          "properties": {
            "softDeletePeriod": "P30D",
            "hotCachePeriod": "P7D"
          }
        }'
      
      # Create tables for real-time data
      az rest --method POST \
        --uri "https://api.fabric.microsoft.com/v1/workspaces/${each.key}/kqldatabases/tables" \
        --headers "Content-Type=application/json" \
        --body '{
          "tables": [
            {
              "name": "RawEvents",
              "schema": "Timestamp:datetime, EventData:dynamic, Source:string"
            },
            {
              "name": "ProcessedMetrics",
              "schema": "Timestamp:datetime, MetricName:string, Value:real, Tags:dynamic"
            }
          ]
        }'
    EOT
  }
  
  depends_on = [null_resource.fabric_workspaces]
}

# Data Warehouse Configuration
resource "null_resource" "fabric_data_warehouses" {
  for_each = {
    for k, v in var.workspace_configuration : k => v
    if contains(v.features, "data_warehouse")
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      # Create Data Warehouse
      az rest --method POST \
        --uri "https://api.fabric.microsoft.com/v1/workspaces/${each.key}/warehouses" \
        --headers "Content-Type=application/json" \
        --body '{
          "displayName": "${each.value.name}-warehouse",
          "description": "Data warehouse for ${each.value.description}"
        }'
    EOT
  }
  
  depends_on = [null_resource.fabric_workspaces]
}

# Data Pipeline Templates
resource "null_resource" "fabric_pipelines" {
  for_each = var.workspace_configuration
  
  provisioner "local-exec" {
    command = <<-EOT
      # Create ingestion pipeline
      az rest --method POST \
        --uri "https://api.fabric.microsoft.com/v1/workspaces/${each.key}/pipelines" \
        --headers "Content-Type=application/json" \
        --body '{
          "displayName": "${each.value.name}-ingestion-pipeline",
          "definition": {
            "activities": [
              {
                "name": "CopyFromSource",
                "type": "Copy",
                "inputs": [],
                "outputs": [],
                "typeProperties": {
                  "source": {
                    "type": "BinarySource"
                  },
                  "sink": {
                    "type": "LakehouseSink",
                    "lakehouse": "${each.value.name}-lakehouse",
                    "table": "bronze_raw"
                  }
                }
              }
            ]
          }
        }'
      
      # Create transformation pipeline
      az rest --method POST \
        --uri "https://api.fabric.microsoft.com/v1/workspaces/${each.key}/pipelines" \
        --headers "Content-Type=application/json" \
        --body '{
          "displayName": "${each.value.name}-transformation-pipeline",
          "definition": {
            "activities": [
              {
                "name": "TransformData",
                "type": "SparkJob",
                "typeProperties": {
                  "sparkJobDefinition": {
                    "main": "transform.py",
                    "args": ["--source", "bronze", "--target", "silver"]
                  }
                }
              }
            ]
          }
        }'
    EOT
  }
  
  depends_on = [null_resource.fabric_lakehouses]
}

# Semantic Models (formerly Power BI Datasets)
resource "null_resource" "fabric_semantic_models" {
  for_each = var.workspace_configuration
  
  provisioner "local-exec" {
    command = <<-EOT
      # Create semantic model
      az rest --method POST \
        --uri "https://api.fabric.microsoft.com/v1/workspaces/${each.key}/semanticmodels" \
        --headers "Content-Type=application/json" \
        --body '{
          "displayName": "${each.value.name}-model",
          "definition": {
            "tables": [
              {
                "name": "FactTable",
                "source": {
                  "type": "lakehouse",
                  "lakehouse": "${each.value.name}-lakehouse",
                  "table": "gold_aggregated"
                }
              }
            ],
            "relationships": [],
            "measures": [
              {
                "name": "TotalTransactions",
                "expression": "COUNT(FactTable[TransactionId])"
              }
            ]
          }
        }'
    EOT
  }
  
  depends_on = [null_resource.fabric_lakehouses]
}

# Fabric Notebooks for Data Science
resource "null_resource" "fabric_notebooks" {
  for_each = {
    for k, v in var.workspace_configuration : k => v
    if contains(v.features, "data_science")
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      # Create ML notebook
      az rest --method POST \
        --uri "https://api.fabric.microsoft.com/v1/workspaces/${each.key}/notebooks" \
        --headers "Content-Type=application/json" \
        --body '{
          "displayName": "${each.value.name}-ml-notebook",
          "definition": {
            "format": "ipynb",
            "defaultLanguage": "python",
            "content": {
              "cells": [
                {
                  "cell_type": "markdown",
                  "source": "# ML Model Training Notebook"
                },
                {
                  "cell_type": "code",
                  "source": "from pyspark.sql import SparkSession\nfrom pyspark.ml import Pipeline\n# ML code here"
                }
              ]
            }
          }
        }'
    EOT
  }
  
  depends_on = [null_resource.fabric_workspaces]
}

# Environment Setup for each workspace
resource "null_resource" "fabric_environments" {
  for_each = var.workspace_configuration
  
  provisioner "local-exec" {
    command = <<-EOT
      # Create Spark environment
      az rest --method POST \
        --uri "https://api.fabric.microsoft.com/v1/workspaces/${each.key}/environments" \
        --headers "Content-Type=application/json" \
        --body '{
          "displayName": "${each.value.name}-spark-env",
          "description": "Spark environment for ${each.value.description}",
          "environmentType": "Spark",
          "sparkVersion": "3.4",
          "pythonVersion": "3.10",
          "libraries": {
            "python": [
              "pandas==2.0.3",
              "numpy==1.24.3",
              "scikit-learn==1.3.0",
              "xgboost==1.7.6",
              "mlflow==2.5.0"
            ],
            "jar": [],
            "wheel": []
          }
        }'
    EOT
  }
  
  depends_on = [null_resource.fabric_workspaces]
}

# Outputs
output "fabric_capacity_id" {
  value = azurerm_fabric_capacity.main.id
  description = "Fabric capacity resource ID"
}

output "fabric_capacity_name" {
  value = azurerm_fabric_capacity.main.name
  description = "Fabric capacity name"
}

output "workspace_urls" {
  value = {
    for k, v in var.workspace_configuration : 
    k => "https://app.fabric.microsoft.com/groups/${k}"
  }
  description = "URLs for accessing Fabric workspaces"
}