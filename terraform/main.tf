terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state so every CI run shares the SAME state instead of
  # starting empty and trying to recreate everything from scratch.
  # This bucket must exist BEFORE the first `terraform init` — create it
  # once, manually, with versioning enabled (see BOOTSTRAP.md).
  backend "s3" {
    bucket       = "enterprise-etl-tfstate-unique-identifier"
    key          = "enterprise-etl/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "Production"
      Project     = "EnterpriseETLPipeline"
      ManagedBy   = "Terraform"
    }
  }
}