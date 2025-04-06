resource "aws_lambda_function" "data_fetcher" {
  function_name = "alpha-vantage-fetcher"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "get-api.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30
  memory_size   = 256

  filename = "get-api.zip"

  environment {
    variables = {
      SECRET_NAME  = aws_secretsmanager_secret.alpha_vantage.name
      S3_BUCKET    = aws_s3_bucket.raw_data.id
      DYNAMO_TABLE = aws_dynamodb_table.processed_data.name
    }
  }
}
