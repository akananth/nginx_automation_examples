terraform {
  backend "s3" {
    bucket         = "s3-bucket"       # Your S3 bucket name
    key            = "eks/terraform.tfstate"       # Path to state file
    region         = "us-east-1"                     # AWS region
    dynamodb_table = "terraform-lock-table"          # DynamoDB table for state locking
    encrypt        = true                        
  }
}
