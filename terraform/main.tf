terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Recommended stable version
    }
  }
}

provider "aws" {
  region = "ap-south-1" # Set your preferred region
}
