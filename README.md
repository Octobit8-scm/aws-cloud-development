# AWS Cloud Infrastructure as Code

This repository contains Infrastructure as Code (IaC) for AWS cloud resources using Terraform. The infrastructure includes a secure VPC setup with public and private subnets, along with an EC2 instance deployment.

## Infrastructure Overview

### VPC Architecture

- Custom VPC with DNS support
- Public and Private subnets across multiple Availability Zones
- Internet Gateway for public internet access
- NAT Gateway for private subnet internet access
- Route Tables for both subnet types
- Security Groups with restricted access

### EC2 Instance Configuration

- Instance deployed in private subnet
- Security group with restricted access
- IAM role and instance profile
- CloudWatch agent integration
- Encrypted root volume
- IMDSv2 requirement enabled

## Directory Structure

```
.
├── terraform/
│   ├── vpc.tf              # VPC and networking resources
│   ├── instance.tf         # EC2 instance configuration
│   ├── variables.tf        # Variable definitions
│   ├── outputs.tf          # Output definitions
│   └── providers.tf        # Provider configuration
├── .github/
│   └── workflows/
│       ├── ci.yml          # Main CI pipeline
│       └── kics-scan.yml   # Security scanning workflow
└── README.md
```

## Prerequisites

- Terraform (version 1.5.0 or later)
- AWS CLI configured with appropriate credentials
- GitHub Actions enabled (for CI/CD)
- AWS account with necessary permissions

## Quick Start

1. Clone the repository:

   ```bash
   git clone <repository-url>
   cd aws-cloud-development
   ```

2. Navigate to the terraform directory:

   ```bash
   cd terraform
   ```

3. Initialize Terraform:

   ```bash
   terraform init
   ```

4. Review the planned changes:

   ```bash
   terraform plan
   ```

5. Apply the configuration:
   ```bash
   terraform apply
   ```

## Configuration

### Variables

Key variables that can be customized (in `terraform.tfvars`):

```hcl
aws_region = "us-east-1"
project_name = "my-project"
environment = "dev"
vpc_cidr = "10.0.0.0/16"
instance_type = "t3.micro"
```

### Network Configuration

- VPC CIDR: 10.0.0.0/16
- Public Subnets: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
- Private Subnets: 10.0.4.0/24, 10.0.5.0/24, 10.0.6.0/24

## Security Features

### Network Security

- Private subnets with no direct internet access
- NAT Gateway for outbound internet access
- Security groups with principle of least privilege
- Network ACLs for subnet-level security

### Instance Security

- Placement in private subnet
- IMDSv2 requirement enabled
- Root volume encryption
- Security group with minimal required access
- CloudWatch monitoring enabled

## CI/CD Pipeline

### Main CI Pipeline (ci.yml)

The main CI pipeline includes:

1. Terraform format checking
2. Terraform initialization
3. Terraform validation
4. Security scanning (via KICS)
5. Comprehensive result reporting

Triggers:

- Push to main/master branches
- Pull requests
- Daily scheduled runs

### Security Scanning (kics-scan.yml)

Dedicated security scanning workflow using KICS:

- Scans IaC for security issues
- Generates SARIF and JSON reports
- Integrates with GitHub Security tab
- Posts results to pull requests

## Outputs

The infrastructure deployment provides several useful outputs:

```hcl
vpc_id                  # VPC ID
public_subnet_ids       # List of public subnet IDs
private_subnet_ids      # List of private subnet IDs
nat_gateway_public_ip   # NAT Gateway public IP
ec2_instance_id         # EC2 instance ID
ec2_private_ip         # EC2 instance private IP
```

## Best Practices Implemented

1. **Security**:

   - Encrypted root volumes
   - IMDSv2 requirement
   - Principle of least privilege
   - Security group restrictions

2. **Networking**:

   - Multi-AZ deployment
   - Private subnet isolation
   - Controlled internet access

3. **Monitoring**:

   - CloudWatch integration
   - Detailed monitoring enabled
   - Instance metrics collection

4. **CI/CD**:
   - Automated code formatting
   - Security scanning
   - Pull request validation
   - Comprehensive reporting

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Security Scanning

The repository uses KICS (Keeping Infrastructure as Code Secure) for security scanning. To run KICS locally:

```bash
docker pull checkmarx/kics:latest
docker run -v $(pwd):/path checkmarx/kics:latest scan -p /path/terraform
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, please open an issue in the GitHub repository.
