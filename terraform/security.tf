# No port 22 anywhere. Ansible reaches both targets over SSM (amazon.aws.aws_ssm),
# so the private group has zero ingress rules and the public group opens only the
# app port plus a single scrape path.

module "public_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name            = "devops-public-sg"
  use_name_prefix = false
  description     = "Web server: app on 80 from anywhere, node_exporter on 9100 from the monitoring server only."
  vpc_id          = module.vpc.vpc_id

  ingress_rules = {
    http = {
      description = "App container, served through Cloudflare."
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = 80
      to_port     = 80
    }
    node_exporter = {
      description = "node_exporter scrape, monitoring server only."
      cidr_ipv4   = "${var.monitoring_private_ip}/32"
      from_port   = 9100
      to_port     = 9100
    }
  }

  egress_rules = {
    all = {
      description = "Outbound for SSM, ECR and apt."
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
    }
  }

  tags = { Name = "devops-public-sg" }
}

# Deliberately no ingress rules at all. The controller and monitoring server are
# reached only through SSM sessions, which are outbound-initiated.
module "private_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name            = "devops-private-sg"
  use_name_prefix = false
  description     = "Controller and monitoring server: no inbound at all, egress via NAT."
  vpc_id          = module.vpc.vpc_id

  egress_rules = {
    all = {
      description = "Outbound for SSM, ECR, Cloudflare Tunnel and apt."
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
    }
  }

  tags = { Name = "devops-private-sg" }
}

# --- One-off migration from the earlier hand-written resources. Remove once applied.

moved {
  from = aws_security_group.public
  to   = module.public_sg.aws_security_group.this[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.public_http
  to   = module.public_sg.aws_vpc_security_group_ingress_rule.this["http"]
}

moved {
  from = aws_vpc_security_group_ingress_rule.public_node_exporter
  to   = module.public_sg.aws_vpc_security_group_ingress_rule.this["node_exporter"]
}

moved {
  from = aws_vpc_security_group_egress_rule.public_all
  to   = module.public_sg.aws_vpc_security_group_egress_rule.this["all"]
}

moved {
  from = aws_security_group.private
  to   = module.private_sg.aws_security_group.this[0]
}

moved {
  from = aws_vpc_security_group_egress_rule.private_all
  to   = module.private_sg.aws_vpc_security_group_egress_rule.this["all"]
}
