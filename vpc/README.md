# AWS VPC Infrastructure

This Terraform configuration creates a secure VPC infrastructure in AWS with the following components:

- VPC with custom CIDR block
- Public and Private Subnets across multiple Availability Zones
- Internet Gateway for public internet access
- NAT Gateway for private subnet internet access
- Route Tables for both public and private subnets
- Security Groups for public and private subnets

## Prerequisites

- Terraform installed (version 1.0.0 or later)
- AWS CLI configured with appropriate credentials
- AWS account with necessary permissions

## Configuration

The configuration uses the following default values (can be overridden using a `terraform.tfvars` file):

- AWS Region: us-east-1
- VPC CIDR: 10.0.0.0/16
- Public Subnets: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
- Private Subnets: 10.0.4.0/24, 10.0.5.0/24, 10.0.6.0/24
- Availability Zones: us-east-1a, us-east-1b, us-east-1c

## Usage

1. Initialize Terraform:

   ```bash
   terraform init
   ```

2. Review the planned changes:

   ```bash
   terraform plan
   ```

3. Apply the configuration:

   ```bash
   terraform apply
   ```

4. To destroy the infrastructure:
   ```bash
   terraform destroy
   ```

## Security Features

- Public subnets have direct internet access through Internet Gateway
- Private subnets have internet access through NAT Gateway
- Security groups are configured with:
  - Public subnets: Allow inbound HTTP (80) and HTTPS (443)
  - Private subnets: Allow inbound traffic from public subnets only
  - Both subnets: Allow all outbound traffic

## Outputs

The configuration provides the following outputs:

- VPC ID and CIDR block
- Public and Private Subnet IDs
- Public and Private Security Group IDs
- NAT Gateway Public IP

## Customization

To customize the configuration, create a `terraform.tfvars` file with your desired values:

```hcl
aws_region = "us-west-2"
project_name = "my-custom-project"
environment = "prod"
vpc_cidr = "172.16.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b"]
public_subnet_cidrs = ["172.16.1.0/24", "172.16.2.0/24"]
private_subnet_cidrs = ["172.16.3.0/24", "172.16.4.0/24"]
```

## Security Scanning with KICS

This project includes KICS (Keeping Infrastructure as Code Secure) scanning for static analysis of the Terraform code. KICS helps identify security vulnerabilities, compliance issues, and misconfigurations in your infrastructure code.

### KICS Configuration

The KICS scanning is configured through:

- `.github/workflows/kics-scan.yml`: GitHub Actions workflow for automated scanning
- `kics.config.json`: KICS configuration file
- `.kicsignore`: File to exclude certain paths from scanning

### Running KICS Locally

To run KICS locally:

1. Install KICS:

   ```bash
   docker pull checkmarx/kics:latest
   ```

2. Run the scan:
   ```bash
   docker run -v $(pwd):/path checkmarx/kics:latest scan -p /path/vpc -o /path/kics-results
   ```

### KICS Scan Results

The scan results will be available in the `kics-results` directory in JSON format. The GitHub Actions workflow will:

- Run scans on push to main/master branches
- Run scans on pull requests
- Run daily scheduled scans
- Upload results as artifacts
- Fail the workflow if high-severity issues are found

### Customizing KICS Scanning

You can customize the KICS scanning behavior by:

1. Modifying `kics.config.json` to adjust scanning parameters
2. Updating `.kicsignore` to exclude specific files or directories
3. Modifying the GitHub Actions workflow to change when and how scans are performed
