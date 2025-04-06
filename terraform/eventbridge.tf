resource "aws_cloudwatch_event_rule" "daily_stock_fetch" {
  name                = "daily-stock-data-fetch"
  description         = "Triggers Lambda every weekday after market close"
  schedule_expression = "cron(0 20 ? * MON-FRI *)" # 8PM UTC = 4PM ET (market close + buffer)
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_stock_fetch.name
  target_id = "TriggerStockLambda"
  arn       = aws_lambda_function.data_fetcher.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_fetcher.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_stock_fetch.arn
}
