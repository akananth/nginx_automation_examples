terraform {
  backend "s3" {
    bucket         = "aws5-terraform"       # Your S3 bucket name
    key            = "infra/terraform.tfstate"       # Path to state file
    region         = "us-east-1"                     # AWS region
    dynamodb_table = "terraform-lock-table"          # DynamoDB table for state locking
    encrypt        = true                        
  }
}
