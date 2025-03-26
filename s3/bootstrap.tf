data "aws_s3_bucket" "state_bucket" {
  bucket = var.tf_state_bucket
}

locals {
  bucket_exists = can(data.aws_s3_bucket.state_bucket.id)  # Returns `true`/`false` without errors
}

# Check if bucket exists (works even when bucket is missing)
data "aws_s3_bucket" "state_bucket" {
  count = var.check_bucket_exists ? 1 : 0
  bucket = var.tf_state_bucket
}

locals {
  # Returns true if bucket exists, false otherwise (no error)
  bucket_exists = var.check_bucket_exists ? length(data.aws_s3_bucket.state_bucket) > 0 && data.aws_s3_bucket.state_bucket[0].id != "" : false
}

# Create bucket only if it doesn't exist
resource "aws_s3_bucket" "terraform_state_bucket" {
  count = local.bucket_exists ? 0 : 1
  
  bucket        = var.tf_state_bucket
  force_destroy = true
  
  tags = {
    Name = "Terraform State Bucket"
  }
}

# Configure versioning (only if bucket is new)
resource "aws_s3_bucket_versioning" "state_bucket" {
  count = local.bucket_exists ? 0 : 1

  bucket = aws_s3_bucket.terraform_state_bucket[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# Configure encryption (only if bucket is new)
resource "aws_s3_bucket_server_side_encryption_configuration" "state_bucket" {
  count = local.bucket_exists ? 0 : 1

  bucket = aws_s3_bucket.terraform_state_bucket[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Check DynamoDB table existence (using external is fine for DynamoDB)
data "external" "dynamodb_table_check" {
  program = ["bash", "-c", <<EOT
    if aws dynamodb describe-table --table-name terraform-lock-table --region ${var.aws_region} >/dev/null 2>&1; then
      printf '{"exists":"true"}'
    else
      printf '{"exists":"false"}'
    fi
  EOT
  ]
}

# Create DynamoDB table only if missing
resource "aws_dynamodb_table" "terraform_state_lock" {
  count = data.external.dynamodb_table_check.result.exists == "true" ? 0 : 1

  name         = "terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform State Lock Table"
  }
}