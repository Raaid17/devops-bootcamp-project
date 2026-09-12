locals {
  ec2_assume_role = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  state_bucket_arn = "arn:aws:s3:::${var.state_bucket}"
}

# ---------------------------------------------------------------------------
# Web server — SSM agent + pull (never push) the one app image.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "web" {
  name               = "devops-web-role"
  assume_role_policy = local.ec2_assume_role
}

resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "web_ecr_pull" {
  name = "ecr-pull"
  role = aws_iam_role.web.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # GetAuthorizationToken is account-wide by design — it takes no resource.
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = aws_ecr_repository.app.arn
      },
    ]
  })
}

resource "aws_iam_instance_profile" "web" {
  name = "devops-web-profile"
  role = aws_iam_role.web.name
}

# ---------------------------------------------------------------------------
# Ansible controller — opens SSM sessions to the two targets and uses the state
# bucket as the aws_ssm plugin's file-transfer channel.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "controller" {
  name               = "devops-controller-role"
  assume_role_policy = local.ec2_assume_role
}

resource "aws_iam_role_policy_attachment" "controller_ssm" {
  role       = aws_iam_role.controller.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "controller_ansible" {
  name = "ansible-over-ssm"
  role = aws_iam_role.controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Sessions may only be opened against the two managed hosts, never
        # against the controller itself or anything else in the account.
        Effect = "Allow"
        Action = "ssm:StartSession"
        Resource = [
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/${module.web.id}",
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/${module.monitoring.id}",
        ]
      },
      {
        # The plugin drives a non-interactive shell document over that session.
        Effect   = "Allow"
        Action   = "ssm:StartSession"
        Resource = "arn:aws:ssm:${var.region}::document/AWS-StartNonInteractiveCommand"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:TerminateSession",
          "ssm:ResumeSession",
        ]
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:session/*"
      },
      {
        Effect   = "Allow"
        Action   = "ssm:DescribeSessions"
        Resource = "*"
      },
      {
        # Every task's payload travels through this prefix — see ansible/README.
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = "${local.state_bucket_arn}/ansible-transfer/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = local.state_bucket_arn
      },
    ]
  })
}

resource "aws_iam_instance_profile" "controller" {
  name = "devops-controller-profile"
  role = aws_iam_role.controller.name
}

# ---------------------------------------------------------------------------
# Monitoring server — SSM agent plus read of exactly one parameter.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "monitoring" {
  name               = "devops-monitoring-role"
  assume_role_policy = local.ec2_assume_role
}

resource "aws_iam_role_policy_attachment" "monitoring_ssm" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "monitoring_tunnel_token" {
  name = "read-tunnel-token"
  role = aws_iam_role.monitoring.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.tunnel_token_parameter}"
    }]
  })
}

resource "aws_iam_instance_profile" "monitoring" {
  name = "devops-monitoring-profile"
  role = aws_iam_role.monitoring.name
}
