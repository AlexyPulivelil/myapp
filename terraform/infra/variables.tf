variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "myapp"
}

# ── VPC outputs (from terraform/vpc) ─────────────────────────────────────────

variable "vpc_id" {
  description = "VPC ID from the vpc module"
  type        = string
  default     = "vpc-0c2b94819476e88f9"
}

variable "public_subnet_ids" {
  description = "Public subnet IDs — EC2 instances"
  type        = list(string)
  default     = ["subnet-0018fa9366ce955d6", "subnet-0bc4f385a46b7856a"]
}

variable "private_subnet_ids" {
  description = "Private subnet IDs — RDS"
  type        = list(string)
  default     = ["subnet-04082b14802948291", "subnet-050917a6c8e3a51b4"]
}

# ── RDS ───────────────────────────────────────────────────────────────────────

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "appuser"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

# ── EC2 ───────────────────────────────────────────────────────────────────────

variable "ec2_instance_type_staging" {
  description = "EC2 instance type for staging"
  type        = string
  default     = "t3.micro"
}

variable "ec2_instance_type_prod" {
  description = "EC2 instance type for production"
  type        = string
  default     = "t3.small"
}

variable "alarm_email" {
  description = "Email for alarm notifications (unused — alarms disabled)"
  type        = string
  default     = ""
}
