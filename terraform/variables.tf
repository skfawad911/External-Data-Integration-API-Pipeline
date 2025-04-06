# variables.tf
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
