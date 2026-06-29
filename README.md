# myapp — Production AWS Infrastructure & CI/CD

A production-grade AWS infrastructure project deploying a containerised Flask REST API to EC2, backed by PostgreSQL RDS, fully managed by Terraform, with automated CI/CD pipelines using GitHub Actions and Docker Hub.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Project Structure](#project-structure)
3. [Prerequisites](#prerequisites)
4. [Infrastructure Setup](#infrastructure-setup)
5. [GitHub Configuration](#github-configuration)
6. [CI/CD Pipelines](#cicd-pipelines)
7. [Monitoring & Logging](#monitoring--logging)
8. [Security Considerations](#security-considerations)
9. [Local Development](#local-development)
10. [API Reference](#api-reference)

---

## Architecture Overview

```
                        Internet
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
┌─────────────────────────┐ ┌─────────────────────────┐
│  EC2 A — Staging        │ │  EC2 B — Production      │
│  t3.micro               │ │  t3.small                │
│  Public subnet (AZ-a)   │ │  Public subnet (AZ-b)    │
│  Docker: myapp :80      │ │  Docker: myapp :80        │
│  Auto-deploy on push    │ │  Manual deploy            │
└────────────┬────────────┘ └────────────┬────────────┘
             │                           │
             └─────────────┬─────────────┘
                           │ port 5432
                           ▼
          ┌────────────────────────────────┐
          │  RDS PostgreSQL 15             │
          │  db.t3.micro                   │
          │  Private subnets (AZ-a, AZ-b) │
          │  Encrypted at rest             │
          └────────────────────────────────┘

VPC: 10.0.0.0/16
Public subnets:  10.0.1.0/24 (AZ-a), 10.0.2.0/24 (AZ-b)
Private subnets: 10.0.101.0/24 (AZ-a), 10.0.102.0/24 (AZ-b)
```

### Architectural Decisions

| Component | Choice | Reason |
|-----------|--------|--------|
| **Compute** | EC2 with Docker | Simple, cost-effective; no orchestration overhead for a single-service app |
| **Container registry** | Docker Hub | No AWS-specific setup required; standard `docker push/pull` workflow |
| **Database** | RDS PostgreSQL 15 | Fully managed — automated backups, encryption, Multi-AZ capable |
| **Secret management** | AWS Secrets Manager | Credentials never touch environment variables, GitHub secrets, or image layers |
| **IAM auth** | EC2 instance role | EC2 fetches secrets using its attached IAM role — no static credentials anywhere |
| **SSH keys** | Terraform `tls_private_key` | Key pair generated and managed by Terraform; PEM stored as GitHub secret |
| **IaC tool** | Terraform | Declarative, repeatable, supports all required AWS resources via official modules |
| **Terraform layout** | Separate `vpc/` and `infra/` folders | VPC can be applied independently; infra references VPC outputs as variables |

---

## Project Structure

```
.
├── app/
│   ├── app.py              # Flask REST API
│   ├── Dockerfile          # Multi-stage build, non-root user
│   └── requirements.txt
├── terraform/
│   ├── vpc/                # VPC, public + private subnets
│   │   ├── provider.tf
│   │   ├── vpc.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── infra/              # RDS, EC2, IAM, Secrets Manager, monitoring
│       ├── provider.tf
│       ├── rds.tf          # RDS + DB subnet group + Secrets Manager
│       ├── ec2.tf          # EC2 staging + production + IAM + SSH key
│       ├── monitoring.tf   # CloudWatch log groups + dashboards
│       ├── variables.tf
│       └── outputs.tf
├── .github/
│   └── workflows/
│       ├── ci.yml          # Build → Trivy scan → push → deploy staging
│       └── deploy-prod.yml # Manual production deploy
├── docker-compose.yml      # Local development only
└── README.md
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| AWS CLI | 2.x |
| Terraform | 1.5+ |
| Docker | 24+ |

You also need:
- An AWS account with permissions for VPC, EC2, RDS, Secrets Manager, IAM, CloudWatch
- A Docker Hub account with a repository named `myapp`
- A GitHub repository with Actions enabled

---

## Infrastructure Setup

### Step 1 — Deploy the VPC

```bash
cd terraform/vpc
terraform init
terraform apply
```

Note the outputs — you will need them for the next step:

```
public_subnet_ids  = ["subnet-xxx", "subnet-yyy"]
private_subnet_ids = ["subnet-aaa", "subnet-bbb"]
vpc_id             = "vpc-zzz"
```

### Step 2 — Deploy the Infrastructure

Update `terraform/infra/variables.tf` with the VPC outputs from Step 1, then:

```bash
cd terraform/infra
terraform init
terraform apply
```

After apply, retrieve the outputs:

```bash
terraform output staging_public_ip       # → STAGING_EC2_IP GitHub secret
terraform output production_public_ip    # → PROD_EC2_IP GitHub secret
terraform output -raw ec2_private_key_pem   # → EC2_SSH_KEY GitHub secret
```

---

## GitHub Configuration

### Secrets

In **Settings → Secrets and variables → Actions**, add:

| Secret | Value |
|--------|-------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub personal access token |
| `STAGING_EC2_IP` | From `terraform output staging_public_ip` |
| `PROD_EC2_IP` | From `terraform output production_public_ip` |
| `EC2_SSH_KEY` | From `terraform output -raw ec2_private_key_pem` |

### Production Environment

1. Go to **Settings → Environments → New environment**, name it `production`
2. Enable **Required reviewers** and add at least one reviewer
3. The production deploy workflow pauses here until a reviewer approves

---

## CI/CD Pipelines

### Pipeline 1 & 2 — `ci.yml`: Build & Deploy Staging

**Trigger:** Every push to `main`

```
Push to main
    │
    ▼
Job 1: Build & Push
    ├── Checkout code
    ├── Build Docker image (tagged sha-<commit>)
    ├── Trivy vulnerability scan (HIGH/CRITICAL — non-blocking)
    ├── Upload scan results to GitHub Security tab
    └── Push image to Docker Hub
    │
    ▼
Job 2: Deploy to Staging  (runs only if Job 1 succeeds)
    ├── SSH into staging EC2
    ├── Fetch DATABASE_URL from Secrets Manager via instance role
    ├── Pull new image from Docker Hub
    ├── Replace running container (logs → CloudWatch)
    └── Smoke test: GET /health must return HTTP 200
```

### Pipeline 3 — `deploy-prod.yml`: Deploy to Production

**Trigger:** Manual via **Actions → Deploy to Production → Run workflow**

```
Manual trigger (optional image tag input)
    │
    ▼
List last 10 Docker Hub tags
    │
    ▼
Resolve tag (use input or auto-resolve latest)
    │
    ▼
Pause: production environment approval gate
    │
    ▼
SSH into production EC2
    ├── Fetch DATABASE_URL from Secrets Manager
    ├── Pull specified image
    ├── Replace running container
    └── Health check: 6 attempts × 10 seconds
```

---

## Monitoring & Logging

### Centralised Logging

Application logs are shipped directly from Docker to **CloudWatch Logs** using the `awslogs` driver:

| Log Group | Environment |
|-----------|-------------|
| `/myapp/staging` | Staging EC2 container logs |
| `/myapp/production` | Production EC2 container logs |

Retention: 30 days

### CloudWatch Dashboards

Two dashboards are provisioned by Terraform:

**`myapp-application`**

| Widget | Metrics |
|--------|---------|
| EC2 CPU Utilization | Staging + Production CPU % |
| EC2 Network In/Out | Inbound + Outbound bytes per instance |
| Recent Application Errors | CloudWatch Logs Insights — ERROR lines from both environments |
| Application Logs | Last 100 log lines from both environments |

**`myapp-infrastructure`**

| Widget | Metrics |
|--------|---------|
| RDS CPU Utilization | Database CPU % |
| RDS Database Connections | Active connections |
| RDS Free Storage Space | Available disk space |
| RDS Read/Write Latency | Query response times |

---

## Security Considerations

### Secrets Management

- Database password is generated by Terraform (`random_password`) and stored **only** in AWS Secrets Manager
- The app fetches `DATABASE_URL` at deploy time using the EC2 IAM instance role — the credential is never stored in GitHub secrets, environment files, or the Docker image
- Secrets Manager secret is scoped to the exact ARN in the IAM policy — principle of least privilege

### Network Isolation

- RDS lives in **private subnets** with no internet gateway route — it is unreachable from the internet
- RDS security group only allows port 5432 from the EC2 security groups — no public CIDR access
- EC2 instances are in public subnets but the app port (80) and SSH (22) are the only open ingress rules

### Container Security

- Docker image uses a **multi-stage build** — only runtime dependencies in the final image
- Container runs as **non-root user (UID 1000)** — no root access inside the container
- Every image is scanned with **Trivy** for HIGH and CRITICAL CVEs before being pushed to Docker Hub
- Scan results are uploaded to the **GitHub Security tab** for tracking

### IAM

- EC2 instance role has two inline policies: `secretsmanager:GetSecretValue` (scoped to one secret ARN) and CloudWatch Logs write access
- `AmazonSSMManagedInstanceCore` is attached for SSM access without needing open SSH in emergencies

### Database

- RDS storage is **encrypted at rest** (`storage_encrypted = true`)
- RDS is not publicly accessible — `publicly_accessible` defaults to `false` in the module
- `deletion_protection = false` for this project (should be `true` in production)

---

## Local Development

```bash
# Start PostgreSQL + app
docker compose up --build

# Health check
curl http://localhost:8080/health

# Create an item
curl -X POST http://localhost:8080/items \
  -H "Content-Type: application/json" \
  -d '{"name": "hello world"}'

# List items
curl http://localhost:8080/items

# Stop and clean up
docker compose down -v
```

`docker-compose.yml` injects `DATABASE_URL` directly — AWS Secrets Manager is not used locally.

---

## API Reference

| Method | Endpoint | Description | Response |
|--------|----------|-------------|----------|
| `GET` | `/health` | Health check — verifies DB connectivity | `200 {"status":"ok","db":"connected"}` |
| `GET` | `/items` | List all items | `200 [{"id":1,"name":"...","created_at":"..."}]` |
| `POST` | `/items` | Create a new item | `201 {"id":1,"name":"...","created_at":"..."}` |

**POST /items request body:**
```json
{ "name": "your item name" }
```
