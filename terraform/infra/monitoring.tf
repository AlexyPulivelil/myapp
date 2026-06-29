# ── CloudWatch Log Groups ─────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "staging" {
  name              = "/myapp/staging"
  retention_in_days = 30
  tags              = { Project = var.project_name, Environment = "staging" }
}

resource "aws_cloudwatch_log_group" "production" {
  name              = "/myapp/production"
  retention_in_days = 30
  tags              = { Project = var.project_name, Environment = "production" }
}

# ── Dashboard 1: Application ──────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "application" {
  dashboard_name = "${var.project_name}-application"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EC2 CPU Utilization"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.staging.id, { label = "Staging" }],
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.production.id, { label = "Production" }]
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EC2 Network In/Out"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.staging.id, { label = "Staging In" }],
            ["AWS/EC2", "NetworkOut", "InstanceId", aws_instance.staging.id, { label = "Staging Out" }],
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.production.id, { label = "Prod In" }],
            ["AWS/EC2", "NetworkOut", "InstanceId", aws_instance.production.id, { label = "Prod Out" }]
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title  = "Recent Application Errors"
          view   = "table"
          region = var.aws_region
          query  = "SOURCE '/myapp/staging' | SOURCE '/myapp/production' | fields @timestamp, @logStream, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 50"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "Application Logs - Last 100 Lines"
          view   = "table"
          region = var.aws_region
          query  = "SOURCE '/myapp/staging' | SOURCE '/myapp/production' | fields @timestamp, @logStream, @message | sort @timestamp desc | limit 100"
        }
      }
    ]
  })
}

# ── Dashboard 2: Infrastructure ───────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "infrastructure" {
  dashboard_name = "${var.project_name}-infrastructure"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "RDS CPU Utilization"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", module.rds.db_instance_identifier]
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "RDS Database Connections"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", module.rds.db_instance_identifier]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "RDS Free Storage Space"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", module.rds.db_instance_identifier]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "RDS Read/Write Latency"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", module.rds.db_instance_identifier, { label = "Read" }],
            ["AWS/RDS", "WriteLatency", "DBInstanceIdentifier", module.rds.db_instance_identifier, { label = "Write" }]
          ]
        }
      }
    ]
  })
}
