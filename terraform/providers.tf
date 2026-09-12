terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
  }

  # Bucket created by terraform/bootstrap. use_lockfile replaces the old
  # DynamoDB lock table — S3 holds the lock itself now.
  backend "s3" {
    bucket       = "devops-bootcamp-terraform-raaid17"
    key          = "final-project/terraform.tfstate"
    region       = "ap-southeast-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "devops-bootcamp-final-project"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
