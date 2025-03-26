terraform {
  backend "s3" {
    bucket         = "aws5-terraform" # Replace with your actual bucket name
    key            = "nap/terraform.tfstate"       # Path to state file
    region         = "us-east-1"                     # AWS region
    dynamodb_table = "terraform-lock-table"          # DynamoDB table for state locking
    encrypt        = true                            # Encrypt state file at rest
  }
}
