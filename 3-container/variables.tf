variable "name" {
  description = "Name tag for the EC2 instance. CI sets TF_VAR_name=rearc-quest-<commit sha>."
  type        = string
  default     = "rearc-quest"
}

locals {
  # Production lives in the default workspace (the committed terraform.tfstate).
  # Any other workspace, e.g. CI's ci-<sha>, is throwaway. The CI IAM role can only
  # modify or delete resources tagged Environment=ci (see 0-github-actions-oidc/main.tf).
  environment = terraform.workspace == "default" ? "production" : "ci"
}


variable "vpc_cidr" {
  description = "CIDR block for main"
  type        = string
  default     = "10.0.0.0/16"
}
