# Bootstrap stack: creates the S3 bucket that holds the main stack's state.
# Local state on purpose — this is the chicken-and-egg stack, so it cannot use
# the backend it is busy creating. Apply once, then never again.

terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region for every resource in this project."
  type        = string
  default     = "ap-southeast-1"
}

variable "state_bucket" {
  description = "Bucket holding the main stack's Terraform state, and doubling as the Ansible SSM file-transfer bucket."
  type        = string
  default     = "devops-bootcamp-terraform-raaid17"
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket

  tags = {
    Name    = var.state_bucket
    Project = "devops-bootcamp-final-project"
  }
}

# Versioning lets a corrupted or truncated state file be rolled back by hand.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State and the SSM transfer payloads both live here; neither should ever be public.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# The aws_ssm connection plugin leaves one object per task behind. Nothing reads
# them after the task finishes, so expire them rather than paying to keep them.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-ansible-transfer"
    status = "Enabled"

    filter {
      prefix = "ansible-transfer/"
    }

    expiration {
      days = 1
    }
  }
}

output "state_bucket" {
  description = "Feed this to the main stack's backend block."
  value       = aws_s3_bucket.state.id
}
