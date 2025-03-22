# Enable IAM Access Analyzer for the organization/account
resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "${var.project_name}-analyzer"
  type          = "ACCOUNT" # or "ORGANIZATION" if using AWS Organizations

  tags = {
    Name        = "${var.project_name}-access-analyzer"
    Environment = var.environment
  }
}

# Create CloudWatch Log Group for Access Analyzer findings
resource "aws_cloudwatch_log_group" "access_analyzer" {
  name              = "/aws/accessanalyzer/${var.project_name}"
  retention_in_days = var.analyzer_log_retention_days
  kms_key_id        = aws_kms_key.analyzer.arn

  tags = {
    Name        = "${var.project_name}-access-analyzer-logs"
    Environment = var.environment
  }
}

# Create KMS Key for Access Analyzer Logs
resource "aws_kms_key" "analyzer" {
  description             = "KMS key for Access Analyzer logs encryption"
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
        Sid    = "Allow Access Analyzer Service"
        Effect = "Allow"
        Principal = {
          Service = "access-analyzer.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-analyzer-key"
    Environment = var.environment
  }
}

# Create KMS Alias for Access Analyzer
resource "aws_kms_alias" "analyzer" {
  name          = "alias/${var.project_name}-analyzer"
  target_key_id = aws_kms_key.analyzer.key_id
}

# Create SNS Topic for Access Analyzer Alerts
resource "aws_sns_topic" "access_analyzer_alerts" {
  name              = "${var.project_name}-access-analyzer-alerts"
  kms_master_key_id = aws_kms_key.analyzer.id

  tags = {
    Name        = "${var.project_name}-access-analyzer-alerts"
    Environment = var.environment
  }
}

# Create SNS Topic Policy
resource "aws_sns_topic_policy" "access_analyzer_alerts" {
  arn = aws_sns_topic.access_analyzer_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Allow Access Analyzer Service"
        Effect = "Allow"
        Principal = {
          Service = "access-analyzer.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.access_analyzer_alerts.arn
      }
    ]
  })
}

# Create EventBridge Rule for Access Analyzer Findings
resource "aws_cloudwatch_event_rule" "access_analyzer_findings" {
  name        = "${var.project_name}-access-analyzer-findings"
  description = "Capture all Access Analyzer findings"

  event_pattern = jsonencode({
    source      = ["aws.access-analyzer"]
    detail-type = ["Access Analyzer Finding"]
  })

  tags = {
    Name        = "${var.project_name}-access-analyzer-findings"
    Environment = var.environment
  }
}

# Create EventBridge Target for SNS
resource "aws_cloudwatch_event_target" "access_analyzer_sns" {
  rule      = aws_cloudwatch_event_rule.access_analyzer_findings.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.access_analyzer_alerts.arn

  input_transformer {
    input_paths = {
      finding     = "$.detail.finding"
      accountId   = "$.detail.accountId"
      resourceArn = "$.detail.resource"
    }
    input_template = "\"New Access Analyzer Finding: Resource <resourceArn> in account <accountId> has external access. Finding details: <finding>\""
  }
}
