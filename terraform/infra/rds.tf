resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow PostgreSQL from EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.staging_ec2.id, aws_security_group.prod_ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-rds-sg", Project = var.project_name }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = { Name = "${var.project_name}-db-subnet-group", Project = var.project_name }
}

resource "random_password" "db" {
  length  = 24
  special = false
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.project_name}-db"

  engine               = "postgres"
  engine_version       = "15"
  family               = "postgres15"
  major_engine_version = "15"
  instance_class       = var.db_instance_class

  allocated_storage = 20
  storage_encrypted = true

  db_name                     = "appdb"
  username                    = var.db_username
  password                    = random_password.db.result
  manage_master_user_password = false
  port                        = 5432

  multi_az               = false
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot = true
  deletion_protection = false

  tags = { Project = var.project_name }
}

# ── Secrets Manager — store DATABASE_URL after RDS is created ─────────────────

resource "aws_secretsmanager_secret" "db_url" {
  name                    = "myapp/database-url"
  recovery_window_in_days = 0

  tags = { Project = var.project_name }
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id = aws_secretsmanager_secret.db_url.id
  secret_string = jsonencode({
    DATABASE_URL = "postgresql://${var.db_username}:${random_password.db.result}@${module.rds.db_instance_endpoint}/appdb"
  })
}
