# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name        = "${var.project_name}-nat-eip"
    Environment = var.environment
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.project_name}-nat"
    Environment = var.environment
  }
}

# Create Public Subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Disable automatic public IP assignment
  map_public_ip_on_launch = false

  tags = {
    Name                     = "${var.project_name}-public-subnet-${count.index + 1}"
    Environment              = var.environment
    Type                     = "Public"
    "kubernetes.io/role/elb" = "1" # Tag for AWS Load Balancer controller if using k8s
  }
}

# Create Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Ensure no public IPs are assigned
  map_public_ip_on_launch = false

  tags = {
    Name                              = "${var.project_name}-private-subnet-${count.index + 1}"
    Environment                       = var.environment
    Type                              = "Private"
    "kubernetes.io/role/internal-elb" = "1" # Tag for AWS Load Balancer controller if using k8s
  }
}

# Create Firewall Subnets
resource "aws_subnet" "firewall" {
  count             = length(var.firewall_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.firewall_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Ensure no public IPs are assigned
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project_name}-firewall-subnet-${count.index + 1}"
    Environment = var.environment
    Type        = "Firewall"
  }
}

# Create Firewall Route Table
resource "aws_route_table" "firewall" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-firewall-rt"
    Environment = var.environment
  }
}

# Associate Firewall Subnets with Firewall Route Table
resource "aws_route_table_association" "firewall" {
  count          = length(var.firewall_subnet_cidrs)
  subnet_id      = aws_subnet.firewall[count.index].id
  route_table_id = aws_route_table.firewall.id
}

# Create Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

# Create route for public subnet through Network Firewall
resource "aws_route" "public_through_firewall" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = tolist(aws_networkfirewall_firewall.main.firewall_status[0].sync_states)[0].attachment[0].endpoint_id

  depends_on = [aws_networkfirewall_firewall.main]
}

# Create Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-private-rt"
    Environment = var.environment
  }
}

# Create route for private subnet through Network Firewall
resource "aws_route" "private_through_firewall" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = tolist(aws_networkfirewall_firewall.main.firewall_status[0].sync_states)[0].attachment[0].endpoint_id

  depends_on = [aws_networkfirewall_firewall.main]
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Create Security Group for Public Subnets
resource "aws_security_group" "public" {
  name        = "${var.project_name}-public-sg"
  description = "Security group for public subnets"
  vpc_id      = aws_vpc.main.id

  # Allow inbound HTTP only from allowed CIDR blocks
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
    description = "Allow HTTP access from specified IPs only"
  }

  # Allow inbound HTTPS only from allowed CIDR blocks
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_https_cidrs
    description = "Allow HTTPS access from specified IPs only"
  }

  # Allow outbound HTTP/HTTPS for updates through VPC endpoints
  egress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
    description     = "Allow HTTP outbound for updates via S3 endpoint"
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
    description     = "Allow HTTPS outbound for updates via S3 endpoint"
  }

  tags = {
    Name        = "${var.project_name}-public-sg"
    Environment = var.environment
  }
}

# Create Security Group for Private Subnets
resource "aws_security_group" "private" {
  name        = "${var.project_name}-private-sg"
  description = "Security group for private subnets"
  vpc_id      = aws_vpc.main.id

  # Allow outbound HTTP/HTTPS for updates through VPC endpoints
  egress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
    description     = "Allow HTTP outbound for updates via S3 endpoint"
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
    description     = "Allow HTTPS outbound for updates via S3 endpoint"
  }

  tags = {
    Name        = "${var.project_name}-private-sg"
    Environment = var.environment
  }
}

# Create Security Group Rules for Private Subnet (separate to avoid circular dependency)
resource "aws_security_group_rule" "private_ingress_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.public.id
  security_group_id        = aws_security_group.private.id
  description              = "Allow HTTP from public security group only"
}

resource "aws_security_group_rule" "private_ingress_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.public.id
  security_group_id        = aws_security_group.private.id
  description              = "Allow HTTPS from public security group only"
}

resource "aws_security_group_rule" "public_egress_private" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.private.id
  security_group_id        = aws_security_group.public.id
  description              = "Allow all outbound traffic to private security group"
}

# Create S3 VPC Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  tags = {
    Name        = "${var.project_name}-s3-endpoint"
    Environment = var.environment
  }
}

# Associate S3 VPC Endpoint with Route Tables
resource "aws_vpc_endpoint_route_table_association" "public_s3" {
  route_table_id  = aws_route_table.public.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  route_table_id  = aws_route_table.private.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

# Create CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.project_name}-flow-logs"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = aws_kms_key.flow_logs.arn

  tags = {
    Name        = "${var.project_name}-flow-logs"
    Environment = var.environment
  }
}

# Create KMS Key for Flow Logs Encryption
resource "aws_kms_key" "flow_logs" {
  description             = "KMS key for VPC flow logs encryption"
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
    Name        = "${var.project_name}-flow-logs-key"
    Environment = var.environment
  }
}

# Create KMS Alias
resource "aws_kms_alias" "flow_logs" {
  name          = "alias/${var.project_name}-flow-logs"
  target_key_id = aws_kms_key.flow_logs.key_id
}

# Create IAM Role for Flow Logs
resource "aws_iam_role" "flow_logs" {
  name = "${var.project_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-flow-logs-role"
    Environment = var.environment
  }
}

# Create IAM Policy for Flow Logs
resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.project_name}-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = aws_kms_key.flow_logs.arn
      }
    ]
  })
}

# Enable VPC Flow Logs
resource "aws_flow_log" "main" {
  iam_role_arn             = aws_iam_role.flow_logs.arn
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.main.id
  max_aggregation_interval = 60

  log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id} $${type} $${tcp-flags} $${pkt-srcaddr} $${pkt-dstaddr} $${region} $${az-id} $${sublocation-type} $${sublocation-id} $${pkt-src-aws-service} $${pkt-dst-aws-service} $${flow-direction} $${traffic-path}"

  tags = {
    Name        = "${var.project_name}-flow-logs"
    Environment = var.environment
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}
