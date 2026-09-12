variable "region" {
  description = "AWS region for every resource in this project."
  type        = string
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "CIDR for devops-vpc. Split into two /25 subnets."
  type        = string
  default     = "10.0.0.0/24"
}

variable "public_subnet_cidr" {
  description = "Public subnet — holds the web server and the NAT gateway."
  type        = string
  default     = "10.0.0.0/25"
}

variable "private_subnet_cidr" {
  description = "Private subnet — holds the Ansible controller and the monitoring server."
  type        = string
  default     = "10.0.0.128/25"
}

variable "az" {
  description = "Single AZ. One AZ keeps the NAT gateway count (and the bill) at one."
  type        = string
  default     = "ap-southeast-1a"
}

variable "web_private_ip" {
  description = "Pinned so prometheus.yaml can hardcode a scrape target that survives a rebuild."
  type        = string
  default     = "10.0.0.5"
}

variable "controller_private_ip" {
  description = "Pinned private IP of the Ansible controller."
  type        = string
  default     = "10.0.0.135"
}

variable "monitoring_private_ip" {
  description = "Pinned private IP of the monitoring server."
  type        = string
  default     = "10.0.0.136"
}

variable "state_bucket" {
  description = "Terraform state bucket, reused as the aws_ssm connection plugin's file-transfer bucket."
  type        = string
  default     = "devops-bootcamp-terraform-raaid17"
}

variable "ecr_repository_name" {
  description = "Private ECR repository holding the app image. Must be lowercase."
  type        = string
  default     = "devops-bootcamp/final-project-raaid17"
}

variable "github_repository" {
  description = "owner/repo allowed to assume the CI deploy role via OIDC."
  type        = string
  default     = "Raaid17/devops-bootcamp-project"
}

variable "tunnel_token_parameter" {
  description = "SSM parameter holding the Cloudflare Tunnel token for the monitoring server."
  type        = string
  default     = "/devops-bootcamp-2026/final-project/tunnel-token"
}

variable "github_subject_patterns" {
  description = <<-EOT
    Allowed values of the OIDC `sub` claim.

    GitHub now issues subjects carrying immutable numeric IDs, e.g.
    "repo:Raaid17@134477393/devops-bootcamp-project@1367038314:ref:refs/heads/main".
    Almost every tutorial still shows the older "repo:owner/name:*" form, which
    simply does not match any more. Both are listed so the role works whichever
    format the token carries; the ID form is the stronger pin, because a repo
    can be renamed or transferred but its id cannot.
  EOT
  type        = list(string)
  default = [
    "repo:Raaid17@134477393/devops-bootcamp-project@1367038314:*",
    "repo:Raaid17/devops-bootcamp-project:*",
  ]
}
