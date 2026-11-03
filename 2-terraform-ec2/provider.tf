provider "aws" {
  region = "us-west-1"

  default_tags {
    tags = {
      Environment = local.environment
    }
  }
}
