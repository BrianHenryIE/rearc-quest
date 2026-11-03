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

output "alb_dns_name" {
  value       = aws_lb.rearc_quest_ecs_alb.dns_name
  description = "The DNS name of the Application Load Balancer."
}