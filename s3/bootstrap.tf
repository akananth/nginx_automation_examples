data "external" "bucket_check" {
  program = ["bash", "-c", <<EOT
    if aws s3api head-bucket --bucket ${var.tf_state_bucket} --region ${var.aws_region} 2>&1 | grep -q '404'; then
      echo '{"exists":"false"}'
    else
      echo '{"exists":"true"}'
    fi
  EOT
  ]
}

locals {
  # Convert string "true"/"false" to boolean
  bucket_exists = data.external.bucket_check.result.exists == "true"
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

# Configure versioning if creating new bucket
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

# Check DynamoDB table existence
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

