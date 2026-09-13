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

# --- One-off migration from the earlier hand-written resources -----------------
# These tell Terraform the existing network now lives inside the module, so it is
# re-labelled instead of destroyed and rebuilt. Remove once applied.

moved {
  from = aws_vpc.main
  to   = module.vpc.aws_vpc.this[0]
}

moved {
  from = aws_subnet.public
  to   = module.vpc.aws_subnet.public[0]
}

moved {
  from = aws_subnet.private
  to   = module.vpc.aws_subnet.private[0]
}

moved {
  from = aws_internet_gateway.main
  to   = module.vpc.aws_internet_gateway.this[0]
}

moved {
  from = aws_eip.nat
  to   = module.vpc.aws_eip.nat[0]
}

moved {
  from = aws_nat_gateway.main
  to   = module.vpc.aws_nat_gateway.this[0]
}

moved {
  from = aws_route_table.public
  to   = module.vpc.aws_route_table.public[0]
}

moved {
  from = aws_route_table.private
  to   = module.vpc.aws_route_table.private[0]
}

moved {
  from = aws_route_table_association.public
  to   = module.vpc.aws_route_table_association.public[0]
}

moved {
  from = aws_route_table_association.private
  to   = module.vpc.aws_route_table_association.private[0]
}

# The old route tables declared their 0.0.0.0/0 routes inline; the module manages
# them as separate aws_route resources, so adopt the existing routes.
import {
  to = module.vpc.aws_route.public_internet_gateway[0]
  id = "rtb-0add9181a373ce846_0.0.0.0/0"
}

import {
  to = module.vpc.aws_route.private_nat_gateway[0]
  id = "rtb-0cad6ce3681f7734c_0.0.0.0/0"
}
