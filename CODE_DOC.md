# Infrastructure Documentation

This document outlines the infrastructure components provisioned using Terraform for the Alpha Vantage Public API. It includes compute, storage, secrets, monitoring, and scheduling infrastructure, all deployed on AWS.

---

## ⚙️ Terraform Basics

**Region:** `ap-south-1`  
**Provider:** AWS (`~> 5.0`)  
**Environment:** Defined via `var.environment` (default: `prod`)

---

## 🔑 Secrets Management

**Resource:** `aws_secretsmanager_secret.alpha_vantage`  
Stores the Alpha Vantage API key securely.
- Secret name: `prod/alpha-vantage/api-key`
- Value passed via variable `var.api_key` (marked sensitive)
- Configured with a recovery window of 7 days

---

## 🖥️ Lambda Function

**Resource:** `aws_lambda_function.data_fetcher`
- Runs the API data-fetching logic
- Source code packaged from local zip file
- Environment variable `ENV` set to `var.environment`

**Execution Role:** `aws_iam_role.lambda_exec`
- Assumes Lambda execution role
- Attached policies for S3, DynamoDB, and Secrets Manager access

---

## ⏰ EventBridge Scheduler

- Triggers Event  minutes using a cron schedule

**Target:** Lambda function
- Permissions granted via `aws_lambda_permission.allow_eventbridge`

---

## 📦 Storage Resources

### 🔹 S3: Raw Data Bucket
**Resource:** `aws_s3_bucket.raw_data`
- Dynamically named with prefix `alpha-vantage-raw-`
- Versioning enabled

### 🔹 DynamoDB Table: Processed Data
**Resource:** `aws_dynamodb_table.processed_data`
- Table name: `ProcessedStockData`
- Primary key: `SymbolDate` (string)
- GSI: `SymbolIndex` on `Symbol`

---

## 📊 Monitoring & Logging

### 📈 CloudWatch Dashboard: `ApiPipeline`
Includes:
1. **Lambda metrics**: Invocations, Errors, Duration (p99)
2. **Log Insights**: Error frequency from logs
3. **S3 Metrics**: Object count and bucket size

### 🚨 Alarms
**Resource:** `aws_cloudwatch_metric_alarm.pipeline_failure`
- Monitors Lambda errors
- Triggers if >0 errors for 2 consecutive periods (5 min each)
- Notifies SNS topic `aws_sns_topic.pipeline_alerts`

### ✅ Log Metric Filter
**Resource:** `aws_cloudwatch_log_metric_filter.lambda_success`
- Pattern: "Success: Stored"
- Metric: `SuccessCount` in `StockPipeline` namespace

---

## 📦 S3 Inventory for Visibility

**Resource:** `aws_s3_bucket_inventory.raw_data`
- Daily inventory of current objects
- Output format: CSV
- Destination: Same raw bucket (`inventory/` prefix)
- SSE encryption enabled (S3-managed)

---

## 🔐 Terraform Backend - State Storage

**Bucket:** `api-pipeline-terraform-state-prod`
- Versioning enabled
- AES256 server-side encryption
- Public access blocked

Defined in both `secrets.tf` and `state_bucket.tf` (duplicate definitions should be cleaned up).

---

## 📥 Input Variables

```hcl
variable "api_key" {
  type        = string
  description = "Alpha Vantage API key"
  sensitive   = true
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Deployment environment"
}
```

## Lambda Function(get-api.py)

This AWS Lambda function does the following:

Gets API Key securely from AWS Secrets Manager.

Fetches stock data (e.g., IBM) from the Alpha Vantage API.

Processes the data into a DynamoDB-friendly format.

Stores raw data in an S3 bucket as a JSON file.

Stores processed data in a DynamoDB table.

It uses environment variables for the secret name, S3 bucket, and DynamoDB table, and includes proper error handling for API limits, timeouts, and AWS service errors.
