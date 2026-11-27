terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "status-page-tfstate-la13thpierre"
    key          = "status-page/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}