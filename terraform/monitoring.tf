# CloudWatch Dashboard - Enhanced with multiple widgets
resource "aws_cloudwatch_dashboard" "pipeline" {
  dashboard_name = "ApiPipeline"

  dashboard_body = jsonencode({
    widgets = [
      # 1. Lambda Execution Metrics
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.data_fetcher.function_name],
            [".", "Errors", ".", ".", { stat : "Sum", color : "#d13212" }],
            [".", "Duration", ".", ".", { stat : "p99", yAxis : "right" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Lambda Performance"
          period  = 300
        }
      },

      # 2. Log Insights Widget (Your existing log query)
      {
        type   = "log"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          query  = "SOURCE '/aws/lambda/${aws_lambda_function.data_fetcher.function_name}' | filter @message like /error|exception/i | stats count(*) by bin(1h)",
          region = "us-east-1",
          title  = "Error Patterns"
        }
      },

      # 3. S3 Inventory Status
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "NumberOfObjects", "StorageType", "AllStorageTypes", "BucketName", aws_s3_bucket.raw_data.id],
            [".", "BucketSizeBytes", ".", "StandardStorage", ".", "."]
          ],
          view   = "singleValue",
          region = "us-east-1",
          title  = "S3 Storage Metrics",
          period = 86400 # Daily
        }
      }
    ]
  })
}

# S3 Inventory - Added filter for CSV output optimization
resource "aws_s3_bucket_inventory" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id
  name   = "daily-inventory"

  included_object_versions = "Current" # Only current objects

  optional_fields = [
    "Size",
    "LastModifiedDate",
    "StorageClass",
    "ETag"
  ]

  schedule {
    frequency = "Daily"
  }

  destination {
    bucket {
      format     = "CSV"
      bucket_arn = aws_s3_bucket.raw_data.arn
      prefix     = "inventory/"
      encryption {
        sse_s3 {} # Use S3-managed encryption
      }
    }
  }
}

# Enhanced CloudWatch Alarm with missing SNS reference fix
resource "aws_cloudwatch_metric_alarm" "pipeline_failure" {
  alarm_name          = "stock-pipeline-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2 # Require 2 consecutive failures
  datapoints_to_alarm = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Triggers when Lambda fails (2 consecutive failures)"
  treat_missing_data  = "notBreaching" # Don't alarm during scheduled off-hours

  dimensions = {
    FunctionName = aws_lambda_function.data_fetcher.function_name
  }

  alarm_actions = [
    aws_sns_topic.pipeline_alerts.arn, # Make sure this matches your SNS topic
    # Add auto-remediation action (e.g., trigger Step Function)
  ]

  ok_actions = [
    aws_sns_topic.pipeline_alerts.arn
  ]
}

# Add metric filter for success events (missing in original)
resource "aws_cloudwatch_log_metric_filter" "lambda_success" {
  name           = "LambdaSuccessCount"
  pattern        = "\"Success: Stored\""
  log_group_name = "/aws/lambda/${aws_lambda_function.data_fetcher.function_name}"

  metric_transformation {
    name      = "SuccessCount"
    namespace = "StockPipeline"
    value     = "1"
  }
}
