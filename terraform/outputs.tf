output "web_instance_id" { value = module.web.id }
output "controller_instance_id" { value = module.controller.id }
output "monitoring_instance_id" { value = module.monitoring.id }

output "web_private_ip" { value = module.web.private_ip }
output "monitoring_private_ip" { value = module.monitoring.private_ip }

output "web_elastic_ip" {
  description = "Point the Cloudflare A record for web.sirbutterfinger.com here."
  value       = aws_eip.web.public_ip
}

output "ecr_repository_url" { value = aws_ecr_repository.app.repository_url }

output "github_actions_role_arn" {
  description = "Set as the AWS_ROLE_ARN repo variable for the deploy workflow."
  value       = aws_iam_role.github_actions.arn
}

output "controller_session_command" {
  description = "How to get onto the controller — the only way in."
  value       = "aws ssm start-session --target ${module.controller.id} --region ${var.region}"
}

output "github_plan_role_arn" {
  description = "Read-only role for the PR plan gate."
  value       = aws_iam_role.github_plan.arn
}
