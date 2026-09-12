# A dedicated bucket, NOT the state bucket.
#
# The aws_ssm connection plugin writes its payloads at bucket root, keyed by
# "<instance-id>/<remote path>" -- it does not honour a prefix. Sharing the state
# bucket would therefore mean granting the controller and both targets object
# access across the whole bucket, Terraform state included. A separate bucket is
# the only way to keep this genuinely least-privilege.

resource "aws_s3_bucket" "ansible_transfer" {
  bucket        = "devops-bootcamp-ansible-transfer-raaid17"
  force_destroy = true

  tags = { Name = "devops-bootcamp-ansible-transfer-raaid17" }
}

resource "aws_s3_bucket_public_access_block" "ansible_transfer" {
  bucket = aws_s3_bucket.ansible_transfer.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Nothing reads these objects once the task finishes.
resource "aws_s3_bucket_lifecycle_configuration" "ansible_transfer" {
  bucket = aws_s3_bucket.ansible_transfer.id

  rule {
    id     = "expire-transfer-objects"
    status = "Enabled"

    filter {}

    expiration {
      days = 1
    }
  }
}
