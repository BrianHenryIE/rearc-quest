# Determine the AWS account ID of the current caller
data "aws_caller_identity" "current" {}

# Determine the region
data "aws_region" "current" {}
