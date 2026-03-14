terraform {
  required_version = ">= 1.8.0"

  backend "s3" {
    bucket         = "replace-me-terraform-state"
    key            = "openshelter/stg/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "replace-me-terraform-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
