resource "aws_sns_topic" "pipeline_alerts" {
  name              = "stock-pipeline-alerts"
  kms_master_key_id = "alias/aws/sns" # Enable AWS-managed encryption
  tags = {
    Purpose = "Notify team about pipeline failures"
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.pipeline_alerts.arn
  protocol  = "email"
  endpoint  = "skfawad911@gmail.com" # Replace with real email
}
