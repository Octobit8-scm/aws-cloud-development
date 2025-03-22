# Enable AWS Shield Advanced
resource "aws_shield_protection" "vpc" {
  name         = "${var.project_name}-vpc-protection"
  resource_arn = aws_vpc.main.arn

  tags = {
    Name        = "${var.project_name}-vpc-protection"
    Environment = var.environment
  }
}

# Create CloudWatch Alarms for DDoS events
resource "aws_cloudwatch_metric_alarm" "ddos_detected" {
  alarm_name          = "${var.project_name}-ddos-detection"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DDoSDetected"
  namespace           = "AWS/DDoSProtection"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors for DDoS attacks"
  alarm_actions       = [aws_sns_topic.shield_alerts.arn]

  dimensions = {
    ResourceArn = aws_vpc.main.arn
  }

  tags = {
    Name        = "${var.project_name}-ddos-alarm"
    Environment = var.environment
  }
}

# Create SNS Topic for Shield Advanced Alerts
resource "aws_sns_topic" "shield_alerts" {
  name              = "${var.project_name}-shield-alerts"
  kms_master_key_id = aws_kms_key.shield.id

  tags = {
    Name        = "${var.project_name}-shield-alerts"
    Environment = var.environment
  }
}

# Create KMS Key for Shield Advanced
resource "aws_kms_key" "shield" {
  description             = "KMS key for Shield Advanced encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Shield Service"
        Effect = "Allow"
        Principal = {
          Service = "shield.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-shield-key"
    Environment = var.environment
  }
}

# Create KMS Alias for Shield
resource "aws_kms_alias" "shield" {
  name          = "alias/${var.project_name}-shield"
  target_key_id = aws_kms_key.shield.key_id
}

# Enable AWS Shield Advanced at the account level
resource "aws_shield_protection_group" "account" {
  protection_group_id = "${var.project_name}-protection-group"
  aggregation         = "MAX"
  pattern             = "ALL"

  tags = {
    Name        = "${var.project_name}-protection-group"
    Environment = var.environment
  }
}

# Create EventBridge Rule for Shield Events
resource "aws_cloudwatch_event_rule" "shield_events" {
  name        = "${var.project_name}-shield-events"
  description = "Capture all Shield Advanced events"

  event_pattern = jsonencode({
    source      = ["aws.shield"]
    detail-type = ["AWS Shield Hub Finding", "AWS Shield Hub Aggregated Finding"]
  })

  tags = {
    Name        = "${var.project_name}-shield-events"
    Environment = var.environment
  }
}

# Create EventBridge Target for Shield Events
resource "aws_cloudwatch_event_target" "shield_sns" {
  rule      = aws_cloudwatch_event_rule.shield_events.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.shield_alerts.arn

  input_transformer {
    input_paths = {
      finding    = "$.detail.findings[0]"
      attackId   = "$.detail.attackId"
      resourceId = "$.detail.resourceId"
    }
    input_template = "\"Shield Advanced Alert: Attack detected on resource <resourceId>. Attack ID: <attackId>. Finding details: <finding>\""
  }
}

# Create Shield Advanced Health Check
resource "aws_shield_protection_health_check_association" "vpc" {
  shield_protection_id = aws_shield_protection.vpc.id
  health_check_arn     = aws_route53_health_check.shield.arn
}

# Create Route53 Health Check for Shield
resource "aws_route53_health_check" "shield" {
  fqdn              = var.domain_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name        = "${var.project_name}-shield-health-check"
    Environment = var.environment
  }
}
