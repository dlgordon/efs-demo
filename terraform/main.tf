terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "> 4.0.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
  assume_role {
    role_arn = "arn:aws:iam::${local.workload_account_id}:role/${local.deployment_role_name}"
  }
}

data "aws_caller_identity" "current" {}
