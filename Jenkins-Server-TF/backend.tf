# Terraform settings.
# We use LOCAL state (no S3 bucket / DynamoDB table needed).
# The state file (terraform.tfstate) is saved in this folder in AWS CloudShell.
# DO NOT delete this folder until you have run "terraform destroy".
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
