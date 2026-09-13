data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# No key_name on any instance: there is no SSH path into this VPC at all.

module "web" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.0"

  name                   = "devops-web-server"
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.public_subnets[0]
  private_ip             = var.web_private_ip
  create_security_group  = false
  vpc_security_group_ids = [module.public_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.web.name

  tags = { Name = "devops-web-server" }
}

# Elastic IP so the Cloudflare A record survives a stop/start of the instance.
resource "aws_eip" "web" {
  domain     = "vpc"
  depends_on = [module.vpc]

  tags = { Name = "devops-web-eip" }
}

resource "aws_eip_association" "web" {
  instance_id   = module.web.id
  allocation_id = aws_eip.web.id
}

module "controller" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.0"

  name                   = "devops-ansible-controller"
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.private_subnets[0]
  private_ip             = var.controller_private_ip
  create_security_group  = false
  vpc_security_group_ids = [module.private_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.controller.name

  user_data                   = file("${path.module}/userdata-controller.sh")
  user_data_replace_on_change = false

  tags = { Name = "devops-ansible-controller" }

  # Without this the instance can boot before the NAT route exists and its
  # first apt/SSM calls fail against an unreachable network.
  depends_on = [module.vpc]
}

# t3.small + 16GB: Prometheus, Grafana and cloudflared on a micro is where the
# grafana bootcamp session ran out of room.
module "monitoring" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.0"

  name                   = "devops-monitoring-server"
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = module.vpc.private_subnets[0]
  private_ip             = var.monitoring_private_ip
  create_security_group  = false
  vpc_security_group_ids = [module.private_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.monitoring.name

  root_block_device = { size = 16 }

  tags = { Name = "devops-monitoring-server" }

  # Without this the instance can boot before the NAT route exists and its
  # first apt/SSM calls fail against an unreachable network.
  depends_on = [module.vpc]
}
