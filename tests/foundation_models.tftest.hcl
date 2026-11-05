# Plan-only tests for the IAM policy granted for foundation models invoked
# directly in the provider's region.
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

# A model that supports on-demand inference in the region.
override_data {
  target = data.aws_bedrock_foundation_model.this["amazon.nova-lite-v1:0"]
  values = {
    model_arn                 = "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-lite-v1:0"
    inference_types_supported = ["ON_DEMAND"]
  }
}

# A model that can only be reached through an inference profile.
override_data {
  target = data.aws_bedrock_foundation_model.this["anthropic.claude-sonnet-4-6"]
  values = {
    model_arn                 = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-6"
    inference_types_supported = ["INFERENCE_PROFILE"]
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

variables {
  project              = "example"
  environment          = "test"
  foundation_model_ids = ["amazon.nova-lite-v1:0"]
}

run "foundation_model_only" {
  command = plan

  assert {
    condition     = length(data.aws_iam_policy_document.invoke.statement) == 1
    error_message = "A foundation model alone must produce a single statement."
  }

  assert {
    condition = alltrue([
      for statement in data.aws_iam_policy_document.invoke.statement :
      toset(statement.actions) == toset(["bedrock:InvokeModel"]) &&
      toset(statement.resources) == toset(["arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-lite-v1:0"]) &&
      length(statement.condition) == 0
    ])
    error_message = "The in-region foundation model must be granted bedrock:InvokeModel without conditions."
  }

  assert {
    condition     = toset(output.model_arns) == toset(["arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-lite-v1:0"])
    error_message = "The model_arns output must include the in-region foundation model."
  }

  assert {
    condition     = output.inference_profile_arns == {}
    error_message = "No inference profiles were declared, so none may be output."
  }
}

run "foundation_models_alongside_profiles" {
  command = plan

  variables {
    allow_streaming       = true
    inference_profile_ids = ["us.anthropic.claude-sonnet-4-6"]
  }

  assert {
    condition = toset(flatten([
      for statement in data.aws_iam_policy_document.invoke.statement :
      statement.resources if length(statement.condition) == 0
      ])) == toset([
      "arn:aws:bedrock:us-east-1:111111111111:inference-profile/us.anthropic.claude-sonnet-4-6",
      "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-lite-v1:0",
    ])
    error_message = "Only the inference profile and the in-region foundation model may be invoked without conditions."
  }

  assert {
    condition = toset(flatten([
      for statement in data.aws_iam_policy_document.invoke.statement :
      statement.resources if length(statement.condition) > 0
      ])) == toset([
      "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-6",
      "arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-sonnet-4-6",
      "arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-sonnet-4-6",
    ])
    error_message = "The profile's foundation models must remain conditioned on the profile."
  }

  assert {
    condition = alltrue([
      for statement in data.aws_iam_policy_document.invoke.statement :
      toset(statement.actions) == toset(["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"])
    ])
    error_message = "With allow_streaming, every statement, including foundation models, must grant the streaming action."
  }

  assert {
    condition = toset(output.model_arns) == toset([
      "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-lite-v1:0",
      "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-6",
      "arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-sonnet-4-6",
      "arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-sonnet-4-6",
    ])
    error_message = "The model_arns output must include both profile and in-region foundation models."
  }
}

run "foundation_model_ids_reject_profile_prefix" {
  command = plan

  variables {
    foundation_model_ids = ["us.amazon.nova-lite-v1:0"]
  }

  expect_failures = [var.foundation_model_ids]
}

# Models such as recent Anthropic models can only be invoked through an
# inference profile; granting them directly would fail at runtime.
run "foundation_model_requires_on_demand" {
  command = plan

  variables {
    foundation_model_ids = ["anthropic.claude-sonnet-4-6"]
  }

  expect_failures = [data.aws_bedrock_foundation_model.this]
}

run "requires_at_least_one_model" {
  command = plan

  variables {
    foundation_model_ids = []
  }

  expect_failures = [aws_iam_policy.this]
}
