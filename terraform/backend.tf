terraform {
  backend "s3" {
    bucket  = "api-pipeline-terraform-state-prod"
    key     = "api-pipeline/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}


