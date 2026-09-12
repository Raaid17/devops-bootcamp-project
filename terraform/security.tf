# No port 22 anywhere. Ansible reaches both targets over SSM (amazon.aws.aws_ssm),
# so the private group has zero ingress rules and the public group opens only the
# app port plus a single scrape path.

resource "aws_security_group" "public" {
  name        = "devops-public-sg"
  description = "Web server: app on 80 from anywhere, node_exporter on 9100 from the monitoring server only."
  vpc_id      = aws_vpc.main.id

  tags = { Name = "devops-public-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "public_http" {
  security_group_id = aws_security_group.public.id
  description       = "App container, served through Cloudflare."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "public_node_exporter" {
  security_group_id = aws_security_group.public.id
  description       = "node_exporter scrape, monitoring server only."
  cidr_ipv4         = "${var.monitoring_private_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 9100
  to_port           = 9100
}

resource "aws_vpc_security_group_egress_rule" "public_all" {
  security_group_id = aws_security_group.public.id
  description       = "Outbound for SSM, ECR and apt."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Deliberately no ingress rules at all. The controller and monitoring server are
# reached only through SSM sessions, which are outbound-initiated.
resource "aws_security_group" "private" {
  name        = "devops-private-sg"
  description = "Controller and monitoring server: no inbound at all, egress via NAT."
  vpc_id      = aws_vpc.main.id

  tags = { Name = "devops-private-sg" }
}

resource "aws_vpc_security_group_egress_rule" "private_all" {
  security_group_id = aws_security_group.private.id
  description       = "Outbound for SSM, ECR, Cloudflare Tunnel and apt."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
