terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.71.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.4.2"
    }
  }
  required_version = ">= 1.17.1"
}
