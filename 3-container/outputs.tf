output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  value = data.aws_caller_identity.current.arn
}

output "caller_user" {
  value = data.aws_caller_identity.current.user_id
}

output "provider_region" {
  value       = data.aws_region.current.region
  description = "The region configured in the AWS provider."
}


# TODO: rearc-quest-ecs-alb DNS name.