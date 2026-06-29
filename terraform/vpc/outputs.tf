output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs — EC2 instances will be placed here"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private subnet IDs — RDS will be placed here"
  value       = module.vpc.private_subnets
}

output "database_subnet_group_name" {
  description = "RDS subnet group name — needed when creating RDS in the next step"
  value       = module.vpc.database_subnet_group_name
}
