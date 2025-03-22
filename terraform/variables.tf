variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "octobit8-org"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "firewall_subnet_cidrs" {
  description = "CIDR blocks for firewall subnets"
  type        = list(string)
  default     = ["10.0.7.0/24", "10.0.8.0/24", "10.0.9.0/24"]
}

variable "blocked_domains" {
  description = "List of domain names to block"
  type        = list(string)
  default = [
    "*.malicious-domain.com",
    "*.suspicious-site.net"
  ]
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP CIDR ranges"
  type        = list(string)
  default = [
    "10.0.0.0/8",    # Internal network
    "172.16.0.0/12", # VPC network
    "192.168.0.0/16" # Private network
  ]
}

# EC2 Instance Variables
variable "instance_ami" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0440d3b780d96b29d" # Amazon Linux 2023 AMI in us-east-1
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 30
}

variable "allowed_http_cidrs" {
  description = "List of CIDR blocks allowed to access HTTP (port 80)"
  type        = list(string)
  default     = ["10.0.0.0/8"] # Default to internal network only
}

variable "allowed_https_cidrs" {
  description = "List of CIDR blocks allowed to access HTTPS (port 443)"
  type        = list(string)
  default     = ["10.0.0.0/8"] # Default to internal network only
}

variable "assign_public_ip" {
  description = "Whether to assign public IPs to instances in the public subnet (should be false by default for security)"
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "Number of days to retain VPC Flow Logs in CloudWatch"
  type        = number
  default     = 30 # 30 days retention by default
}

variable "analyzer_log_retention_days" {
  description = "Number of days to retain Access Analyzer logs in CloudWatch"
  type        = number
  default     = 90 # 90 days retention by default for security audit purposes
}

variable "domain_name" {
  description = "Domain name for Shield Advanced health checks"
  type        = string
  default     = "example.com" # Replace with your actual domain
}
