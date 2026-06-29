module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_nat_gateway   = false
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Project = var.project_name
  }
}
