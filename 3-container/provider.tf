provider "aws" {
  region = "us-west-1"

  default_tags {
    tags = {
      Environment = local.environment
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}