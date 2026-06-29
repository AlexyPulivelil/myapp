# ── SSH key pair ──────────────────────────────────────────────────────────────

resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ec2.public_key_openssh
}

# ── Security groups ───────────────────────────────────────────────────────────

resource "aws_security_group" "staging_ec2" {
  name        = "${var.project_name}-staging-sg"
  description = "Staging EC2 - HTTP + SSH"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-staging-sg", Project = var.project_name }
}

resource "aws_security_group" "prod_ec2" {
  name        = "${var.project_name}-prod-sg"
  description = "Production EC2 - HTTP + SSH"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-prod-sg", Project = var.project_name }
}

# ── IAM role — lets EC2 read Secrets Manager ─────────────────────────────────

resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Project = var.project_name }
}

resource "aws_iam_role_policy" "secrets_read" {
  name = "${var.project_name}-secrets-read"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.db_url.arn
    }]
  })
}

resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "${var.project_name}-cloudwatch-logs"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ── AMI — Amazon Linux 2023 ───────────────────────────────────────────────────

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── User data — install Docker ────────────────────────────────────────────────

locals {
  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y docker
    systemctl enable --now docker
    usermod -aG docker ec2-user
  EOF
  )
}

# ── EC2 A — Staging ───────────────────────────────────────────────────────────

resource "aws_instance" "staging" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.ec2_instance_type_staging
  key_name                    = aws_key_pair.ec2.key_name
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.staging_ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true

  user_data = local.user_data

  tags = {
    Name        = "${var.project_name}-staging"
    Project     = var.project_name
    Environment = "staging"
  }
}

# ── EC2 B — Production ────────────────────────────────────────────────────────

resource "aws_instance" "production" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.ec2_instance_type_prod
  key_name                    = aws_key_pair.ec2.key_name
  subnet_id                   = var.public_subnet_ids[1]
  vpc_security_group_ids      = [aws_security_group.prod_ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true

  user_data = local.user_data

  tags = {
    Name        = "${var.project_name}-production"
    Project     = var.project_name
    Environment = "production"
  }
}
