terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "lab"

  default_tags {
    tags = {
      Project     = "luana_lab"
      Environment = "lab"
      Owner       = "luana"
    }
  }
}