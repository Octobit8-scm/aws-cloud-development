# Create Network Firewall Policy
resource "aws_networkfirewall_firewall_policy" "main" {
  name = "${var.project_name}-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.block_domains.arn
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.allow_traffic.arn
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.drop_unauthorized.arn
    }
  }

  tags = {
    Name        = "${var.project_name}-firewall-policy"
    Environment = var.environment
  }
}

# Create Domain Block Rule Group
resource "aws_networkfirewall_rule_group" "block_domains" {
  capacity = 100
  name     = "${var.project_name}-block-domains"
  type     = "STATEFUL"
  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = var.blocked_domains
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-block-domains"
    Environment = var.environment
  }
}

# Create Drop Unauthorized Traffic Rule Group
resource "aws_networkfirewall_rule_group" "drop_unauthorized" {
  capacity = 100
  name     = "${var.project_name}-drop-unauthorized"
  type     = "STATEFUL"
  rule_group {
    rules_source {
      # Drop unauthorized HTTP traffic
      stateful_rule {
        action = "DROP"
        header {
          destination      = "ANY"
          destination_port = "80"
          protocol         = "TCP"
          direction        = "FORWARD"
          source_port      = "ANY"
          source           = "ANY"
        }
        rule_option {
          keyword = "sid:3"
        }
      }

      # Drop unauthorized HTTPS traffic
      stateful_rule {
        action = "DROP"
        header {
          destination      = "ANY"
          destination_port = "443"
          protocol         = "TCP"
          direction        = "FORWARD"
          source_port      = "ANY"
          source           = "ANY"
        }
        rule_option {
          keyword = "sid:4"
        }
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-drop-unauthorized"
    Environment = var.environment
  }
}

# Create Allow Traffic Rule Group
resource "aws_networkfirewall_rule_group" "allow_traffic" {
  capacity = 100
  name     = "${var.project_name}-allow-traffic"
  type     = "STATEFUL"
  rule_group {
    rule_variables {
      ip_sets {
        key = "ALLOWED_IPS"
        ip_set {
          definition = var.allowed_ip_ranges
        }
      }
    }
    rules_source {
      # Allow HTTP only from authorized IPs
      stateful_rule {
        action = "PASS"
        header {
          destination      = var.vpc_cidr
          destination_port = "80"
          protocol         = "TCP"
          direction        = "FORWARD"
          source_port      = "ANY"
          source           = "$ALLOWED_IPS"
        }
        rule_option {
          keyword = "sid:1"
        }
      }

      # Allow HTTPS only from authorized IPs
      stateful_rule {
        action = "PASS"
        header {
          destination      = var.vpc_cidr
          destination_port = "443"
          protocol         = "TCP"
          direction        = "FORWARD"
          source_port      = "ANY"
          source           = "$ALLOWED_IPS"
        }
        rule_option {
          keyword = "sid:2"
        }
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-allow-traffic"
    Environment = var.environment
  }
}

# Create Network Firewall
resource "aws_networkfirewall_firewall" "main" {
  name                = "${var.project_name}-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
  vpc_id              = aws_vpc.main.id

  dynamic "subnet_mapping" {
    for_each = aws_subnet.firewall[*].id
    content {
      subnet_id = subnet_mapping.value
    }
  }

  tags = {
    Name        = "${var.project_name}-firewall"
    Environment = var.environment
  }
}
