# Plan-only tests for the optional Bedrock Runtime interface VPC endpoint.
#
# The AWS provider is mocked, so these tests make no AWS calls and need no
# credentials. Run with `tofu test` from the repository root, after `tofu init`.

mock_provider "aws" {
  # Mocked values are random strings by default, which fail the provider's
  # policy validation. Tests assert on policy statements instead of this JSON.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }
}

override_data {
  target = data.aws_region.current
  values = {
    region = "us-east-1"
  }
}

override_data {
  target = data.aws_bedrock_foundation_model.this["amazon.nova-lite-v1:0"]
  values = {
    model_arn                 = "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-lite-v1:0"
    inference_types_supported = ["ON_DEMAND"]
  }
}

override_data {
  target = data.aws_bedrock_inference_profile.this["us.anthropic.claude-sonnet-4-6"]
  values = {
    inference_profile_arn = "arn:aws:bedrock:us-east-1:111111111111:inference-profile/us.anthropic.claude-sonnet-4-6"
    models = [
      { model_arn = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-6" },
      { model_arn = "arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-sonnet-4-6" },
      { model_arn = "arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-sonnet-4-6" },
    ]
  }
}

override_resource {
  target = aws_security_group.endpoint["this"]
  values = {
    id = "sg-0endpoint000000000"
  }
}

variables {
  project               = "example"
  environment           = "test"
  inference_profile_ids = ["us.anthropic.claude-sonnet-4-6"]
  foundation_model_ids  = ["amazon.nova-lite-v1:0"]

  endpoint_allowed_security_group_ids = ["sg-0task0000000000000"]
  endpoint_principal_arns             = ["arn:aws:iam::111111111111:role/example-test-task"]
  subnet_ids                          = ["subnet-00000000000000001", "subnet-00000000000000002"]
  vpc_id                              = "vpc-00000000000000000"
}

run "endpoint_disabled_by_default" {
  command = plan

  assert {
    condition     = length(aws_vpc_endpoint.bedrock_runtime) == 0
    error_message = "The VPC endpoint must not be created unless create_vpc_endpoint is set."
  }

  assert {
    condition     = length(aws_security_group.endpoint) == 0
    error_message = "The endpoint security group must not be created unless create_vpc_endpoint is set."
  }

  assert {
    condition     = output.vpc_endpoint_id == null && output.security_group_id == null
    error_message = "The endpoint outputs must be null when the endpoint is not created."
  }
}

run "endpoint" {
  command = plan

  variables {
    create_vpc_endpoint = true
  }

  assert {
    condition     = aws_vpc_endpoint.bedrock_runtime["this"].service_name == "com.amazonaws.us-east-1.bedrock-runtime"
    error_message = "The endpoint must be for Bedrock Runtime in the provider's region."
  }

  assert {
    condition     = aws_vpc_endpoint.bedrock_runtime["this"].vpc_endpoint_type == "Interface"
    error_message = "Bedrock Runtime only supports interface endpoints."
  }

  assert {
    condition     = aws_vpc_endpoint.bedrock_runtime["this"].private_dns_enabled
    error_message = "Private DNS must be enabled so SDKs reach the endpoint without configuration changes."
  }

  assert {
    condition     = aws_vpc_endpoint.bedrock_runtime["this"].vpc_id == "vpc-00000000000000000"
    error_message = "The endpoint must be created in vpc_id."
  }

  assert {
    condition     = toset(aws_vpc_endpoint.bedrock_runtime["this"].subnet_ids) == toset(["subnet-00000000000000001", "subnet-00000000000000002"])
    error_message = "The endpoint must be placed in subnet_ids."
  }

  assert {
    condition     = toset(aws_vpc_endpoint.bedrock_runtime["this"].security_group_ids) == toset(["sg-0endpoint000000000"])
    error_message = "The endpoint must use only the module's endpoint security group."
  }

  assert {
    condition     = aws_security_group.endpoint["this"].name == "example-test-bedrock-runtime"
    error_message = "The endpoint security group must follow the <project>-<environment>-bedrock-runtime naming pattern."
  }

  assert {
    condition     = output.vpc_endpoint_id == aws_vpc_endpoint.bedrock_runtime["this"].id
    error_message = "The vpc_endpoint_id output must be the endpoint's ID."
  }

  assert {
    condition     = output.security_group_id == "sg-0endpoint000000000"
    error_message = "The security_group_id output must be the endpoint security group's ID."
  }
}

# Attributes a rule doesn't set are null in the plan, hence the try()s.
run "security_group_admits_only_allowed_security_groups" {
  command = plan

  variables {
    create_vpc_endpoint = true
  }

  assert {
    condition = length(aws_security_group.endpoint["this"].ingress) == 1 && alltrue([
      for rule in aws_security_group.endpoint["this"].ingress :
      rule.from_port == 443 && rule.to_port == 443 && rule.protocol == "tcp" &&
      toset(rule.security_groups) == toset(["sg-0task0000000000000"])
    ])
    error_message = "The endpoint security group must admit HTTPS only from endpoint_allowed_security_group_ids."
  }

  assert {
    condition = alltrue([
      for rule in aws_security_group.endpoint["this"].ingress :
      try(length(rule.cidr_blocks), 0) == 0 && try(length(rule.ipv6_cidr_blocks), 0) == 0
    ])
    error_message = "The endpoint security group must not admit traffic by CIDR."
  }

  assert {
    condition     = length(aws_security_group.endpoint["this"].egress) == 0
    error_message = "The endpoint security group needs no egress rules."
  }
}

run "endpoint_policy" {
  command = plan

  variables {
    create_vpc_endpoint = true
  }

  assert {
    condition     = aws_vpc_endpoint.bedrock_runtime["this"].policy == data.aws_iam_policy_document.endpoint["this"].json
    error_message = "The endpoint must use the endpoint policy document."
  }

  assert {
    condition = alltrue([
      for statement in data.aws_iam_policy_document.endpoint["this"].statement :
      toset(statement.actions) == toset(["bedrock:InvokeModel"])
    ])
    error_message = "The endpoint must only allow the actions the IAM policy grants."
  }

  assert {
    condition = toset(flatten([
      for statement in data.aws_iam_policy_document.endpoint["this"].statement : statement.resources
      ])) == toset(flatten([
      for statement in data.aws_iam_policy_document.invoke.statement : statement.resources
    ]))
    error_message = "The endpoint must allow exactly the resources the IAM policy grants."
  }

  # The principal is matched by ARN in a condition rather than named directly.
  # A named role principal is stored as the role's unique ID, so recreating the
  # role would silently lock it out while the policy text stayed unchanged.
  assert {
    condition = alltrue([
      for statement in data.aws_iam_policy_document.endpoint["this"].statement :
      anytrue([
        for condition in statement.condition :
        condition.test == "StringEquals" &&
        condition.variable == "aws:PrincipalArn" &&
        toset(condition.values) == toset(["arn:aws:iam::111111111111:role/example-test-task"])
      ])
    ])
    error_message = "Every endpoint policy statement must be limited to endpoint_principal_arns."
  }

  assert {
    condition = toset(flatten([
      for statement in data.aws_iam_policy_document.endpoint["this"].statement :
      statement.resources if anytrue([
        for condition in statement.condition : condition.variable == "bedrock:InferenceProfileArn"
      ])
      ])) == toset([
      "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-6",
      "arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-sonnet-4-6",
      "arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-sonnet-4-6",
    ])
    error_message = "The profile's foundation models must remain conditioned on the profile at the endpoint."
  }
}

run "endpoint_policy_allows_streaming" {
  command = plan

  variables {
    allow_streaming     = true
    create_vpc_endpoint = true
  }

  assert {
    condition = alltrue([
      for statement in data.aws_iam_policy_document.endpoint["this"].statement :
      toset(statement.actions) == toset(["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"])
    ])
    error_message = "With allow_streaming, the endpoint must also allow the streaming action."
  }
}

run "endpoint_requires_vpc_id" {
  command = plan

  variables {
    create_vpc_endpoint = true
    vpc_id              = null
  }

  expect_failures = [aws_vpc_endpoint.bedrock_runtime]
}

run "endpoint_requires_subnet_ids" {
  command = plan

  variables {
    create_vpc_endpoint = true
    subnet_ids          = []
  }

  expect_failures = [aws_vpc_endpoint.bedrock_runtime]
}

run "endpoint_requires_allowed_security_groups" {
  command = plan

  variables {
    create_vpc_endpoint                 = true
    endpoint_allowed_security_group_ids = []
  }

  expect_failures = [aws_vpc_endpoint.bedrock_runtime]
}

run "endpoint_requires_principal_arns" {
  command = plan

  variables {
    create_vpc_endpoint     = true
    endpoint_principal_arns = []
  }

  expect_failures = [aws_vpc_endpoint.bedrock_runtime]
}
