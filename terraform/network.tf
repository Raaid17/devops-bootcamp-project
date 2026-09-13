module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = "devops-vpc"
  cidr = var.vpc_cidr
  azs  = [var.az]

  public_subnets       = [var.public_subnet_cidr]
  public_subnet_names  = ["devops-public-subnet"]
  private_subnets      = [var.private_subnet_cidr]
  private_subnet_names = ["devops-private-subnet"]

  map_public_ip_on_launch = true

  # One NAT gateway in the public subnet serves the private subnet, so the
  # controller and monitoring server can reach SSM, ECR and Cloudflare without
  # being reachable inbound.
  enable_nat_gateway = true
  single_nat_gateway = true

  # The brief grades these exact names. The module's own Name tag comes first in
  # its merge, so these override it.
  igw_tags                 = { Name = "devops-igw" }
  nat_gateway_tags         = { Name = "devops-ngw" }
  nat_eip_tags             = { Name = "devops-ngw-eip" }
  public_route_table_tags  = { Name = "devops-public-route" }
  private_route_table_tags = { Name = "devops-private-route" }

  # Leave the VPC's AWS-created default security group, NACL and route table
  # alone; nothing here uses them.
  manage_default_security_group = false
  manage_default_network_acl    = false
  manage_default_route_table    = false
}
