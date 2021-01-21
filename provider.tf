provider "aws" {
  version = "~> 3.14.1"
  region = "us-west-2"
  profile = "makeen-infra"
}

provider "template" {
  version = "~> 2.1"
}

terraform {
  backend "s3" {
    bucket = "makeen-terraform-states"
    key    = "terraform.tfstate"
    region = "us-west-2"
    dynamodb_table = "makeen-terraform-states"
    profile = "makeen-infra"
  }
}
