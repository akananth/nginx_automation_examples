# Safe S3 bucket existence check
data "external" "bucket_check" {
  program = ["bash", "-c", <<EOT
    if aws s3api head-bucket --bucket ${var.tf_state_bucket} --region ${var.aws_region} 2>/dev/null; then
      echo '{"exists":"true"}'
    else
      echo '{"exists":"false"}'
    fi
  EOT
  ]
}

# Safe DynamoDB table existence check
data "external" "dynamodb_table_check" {
  program = ["bash", "-c", <<EOT
    if aws dynamodb describe-table --table-name terraform-lock-table --region ${var.aws_region} >/dev/null 2>&1; then
      echo '{"exists":"true"}'
    else
      echo '{"exists":"false"}'
    fi
  EOT
  ]
}

locals {
  bucket_exists    = data.external.bucket_check.result.exists == "true"
  dynamodb_exists  = data.external.dynamodb_table_check.result.exists == "true"
}

# S3 Bucket Resources
resource "aws_s3_bucket" "terraform_state" {
  count = local.bucket_exists ? 0 : 1

  bucket        = var.tf_state_bucket
  force_destroy = false  # Safety measure to prevent accidental deletion

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "Global"
  }
}

resource "aws_s3_bucket_versioning" "state_bucket" {
  count = local.bucket_exists ? 0 : 1

  bucket = aws_s3_bucket.terraform_state[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state_bucket" {
  count = local.bucket_exists ? 0 : 1

  bucket = aws_s3_bucket.terraform_state[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  count = local.dynamodb_exists ? 0 : 1

  name         = "terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = "Global"
  }
}