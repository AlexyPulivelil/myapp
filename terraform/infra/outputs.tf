output "staging_public_ip" {
  description = "Staging EC2 public IP — add as STAGING_EC2_IP in GitHub secrets"
  value       = aws_instance.staging.public_ip
}

output "production_public_ip" {
  description = "Production EC2 public IP — add as PROD_EC2_IP in GitHub secrets"
  value       = aws_instance.production.public_ip
}

output "ec2_private_key_pem" {
  description = "SSH private key — add as EC2_SSH_KEY in GitHub secrets"
  value       = tls_private_key.ec2.private_key_pem
  sensitive   = true
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds.db_instance_endpoint
}
