# Changing a security group's description replaces it, which would detach it
# from the endpoint.
resource "aws_security_group" "endpoint" {
  for_each = var.create_vpc_endpoint ? toset(["this"]) : toset([])

  name        = "${local.prefix}-bedrock-runtime"
  description = "Allow HTTPS to the Bedrock Runtime VPC endpoint."
  vpc_id      = var.vpc_id

  # Rules are inline so that OpenTofu removes any added outside it. Without an
  # egress block, the default allow-all egress rule is removed; the endpoint
  # only answers inbound connections.
  ingress {
    description     = "HTTPS from workloads allowed to use Bedrock."
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = var.endpoint_allowed_security_group_ids
  }

  tags = merge(var.tags, { Name = "${local.prefix}-bedrock-runtime" })
}

resource "aws_vpc_endpoint" "bedrock_runtime" {
  for_each = var.create_vpc_endpoint ? toset(["this"]) : toset([])

  policy              = data.aws_iam_policy_document.endpoint["this"].json
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.endpoint["this"].id]
  service_name        = "com.amazonaws.${data.aws_region.current.region}.bedrock-runtime"
  subnet_ids          = var.subnet_ids
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id

  tags = merge(var.tags, { Name = "${local.prefix}-bedrock-runtime" })

  lifecycle {
    precondition {
      condition     = var.vpc_id != null
      error_message = "vpc_id must be set when create_vpc_endpoint is true."
    }

    precondition {
      condition     = length(var.subnet_ids) > 0
      error_message = "subnet_ids must be set when create_vpc_endpoint is true."
    }

    precondition {
      condition     = length(var.endpoint_allowed_security_group_ids) > 0
      error_message = "endpoint_allowed_security_group_ids must be set when create_vpc_endpoint is true."
    }

    precondition {
      condition     = length(var.endpoint_principal_arns) > 0
      error_message = "endpoint_principal_arns must be set when create_vpc_endpoint is true."
    }
  }
}
