terraform {
  required_version = ">= 1.5.7"
  required_providers {
    aws = ">= 5.19.0"
    http = ">= 3.4.0"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Owner = "${var.resource_owner}"
    }
  }
}
