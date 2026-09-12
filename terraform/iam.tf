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
        # The session itself runs through the account-owned shell document.
        # Note the account id in this ARN: SSM-SessionManagerRunShell is owned by
        # the account, unlike the AWS-* documents which have an empty owner field.
        Effect = "Allow"
        Action = "ssm:StartSession"
        Resource = [
          "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:document/SSM-SessionManagerRunShell",
          "arn:aws:ssm:${var.region}::document/AWS-StartNonInteractiveCommand",
        ]
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
        Resource = "${aws_s3_bucket.ansible_transfer.arn}/*"
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

# ---------------------------------------------------------------------------
# The aws_ssm connection plugin ships every task's payload through S3 -- and
# BOTH ends touch the bucket: the controller uploads, the target downloads and
# writes results back. So all three roles need this, not just the controller.
# ---------------------------------------------------------------------------

resource "aws_iam_policy" "ansible_transfer" {
  name        = "devops-ansible-transfer"
  description = "S3 access for the aws_ssm connection plugin's file-transfer channel."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = "${aws_s3_bucket.ansible_transfer.arn}/*"
      },
      {
        # GetBucketLocation is how boto3 resolves the bucket's region before it
        # can sign a request for it; ListBucket is scoped by the same prefix.
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = aws_s3_bucket.ansible_transfer.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ansible_transfer" {
  for_each = {
    controller = aws_iam_role.controller.name
    web        = aws_iam_role.web.name
    monitoring = aws_iam_role.monitoring.name
  }

  role       = each.value
  policy_arn = aws_iam_policy.ansible_transfer.arn
}
