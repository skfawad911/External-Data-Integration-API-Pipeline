resource "aws_secretsmanager_secret" "alpha_vantage" {
  name                    = "prod/alpha-vantage/api-key"
  description             = "Alpha Vantage API Key"
  recovery_window_in_days = 7 
}

resource "aws_secretsmanager_secret_version" "initial" {
  secret_id     = aws_secretsmanager_secret.alpha_vantage.id
  secret_string = var.api_key # Will be passed via variables
}
