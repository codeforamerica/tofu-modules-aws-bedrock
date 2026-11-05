# Plan-only tests for the IAM policy granted for cross-region inference
# profiles.
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

  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::111111111111:policy/example-test-bedrock"
    }
  }
}

# The inference profiles as AWS describes them: one profile ARN in the home
# region, routing to the foundation model in three US regions.
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

override_data {
  target = data.aws_bedrock_inference_profile.this["us.anthropic.claude-haiku-4-5-20251001-v1:0"]
  values = {
    inference_profile_arn = "arn:aws:bedrock:us-east-1:111111111111:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0"
    models = [
      { model_arn = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0" },
      { model_arn = "arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0" },
      { model_arn = "arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0" },
    ]
  }
}

variables {
  project               = "example"
  environment           = "test"
  inference_profile_ids = ["us.anthropic.claude-sonnet-4-6"]
}

run "single_profile_policy" {
  command = plan

  assert {
    condition     = aws_iam_policy.this.name == "example-test-bedrock"
    error_message = "The policy must follow the <project>-<environment>-bedrock naming pattern."
  }

  assert {
    condition     = aws_iam_policy.this.policy == data.aws_iam_policy_document.invoke.json
    error_message = "The policy must use the invoke policy document."
  }

  assert {
    condition = alltrue([
      for statement in data.aws_iam_policy_document.invoke.statement :
      toset(statement.actions) == toset(["bedrock:InvokeModel"])
    ])
    error_message = "Converse and InvokeModel only require bedrock:InvokeModel, so it must be the only action granted by default."
  }

  assert {
    condition = alltrue(flatten([
      for statement in data.aws_iam_policy_document.invoke.statement : [
        for resource in statement.resources : !strcontains(resource, "*")
      ]
    ]))
    error_message = "The policy must not grant wildcard resources."
  }

  assert {
    condition = toset(flatten([
      for statement in data.aws_iam_policy_document.invoke.statement :
      statement.resources if length(statement.condition) == 0
      ])) == toset([
      "arn:aws:bedrock:us-east-1:111111111111:inference-profile/us.anthropic.claude-sonnet-4-6",
    ])
    error_message = "Only the inference profile may be invoked without conditions."
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
    error_message = "The profile's foundation models in every routed region must be granted, and only those."
  }

  assert {
    condition = alltrue(flatten([
      for statement in data.aws_iam_policy_document.invoke.statement : [
        for condition in statement.condition :
        condition.test == "StringEquals" &&
        condition.variable == "bedrock:InferenceProfileArn" &&
        toset(condition.values) == toset(["arn:aws:bedrock:us-east-1:111111111111:inference-profile/us.anthropic.claude-sonnet-4-6"])
      ]
    ]))
    error_message = "Foundation models must only be invocable through the inference profile."
  }

  assert {
    condition = output.inference_profile_arns == {
      "us.anthropic.claude-sonnet-4-6" = "arn:aws:bedrock:us-east-1:111111111111:inference-profile/us.anthropic.claude-sonnet-4-6"
    }
    error_message = "The inference_profile_arns output must map each profile ID to its ARN."
  }

  assert {
    condition = toset(output.model_arns) == toset([
      "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-6",
      "arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-sonnet-4-6",
      "arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-sonnet-4-6",
    ])
    error_message = "The model_arns output must list every granted foundation model."
  }

  assert {
    condition     = output.policy_name == "example-test-bedrock"
    error_message = "The policy_name output must be the policy's name."
  }
}

# Each profile's models must be conditioned on that profile alone, so one
# profile can't be used to reach another profile's models.
run "multiple_profiles_conditioned_separately" {
  command = plan

  variables {
    inference_profile_ids = [
      "us.anthropic.claude-sonnet-4-6",
      "us.anthropic.claude-haiku-4-5-20251001-v1:0",
    ]
  }

  assert {
    condition = toset(flatten([
      for statement in data.aws_iam_policy_document.invoke.statement :
      statement.resources if length(statement.condition) == 0
      ])) == toset([
      "arn:aws:bedrock:us-east-1:111111111111:inference-profile/us.anthropic.claude-sonnet-4-6",
      "arn:aws:bedrock:us-east-1:111111111111:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0",
    ])
    error_message = "Only the inference profiles may be invoked without conditions."
  }

  assert {
    condition     = length([for statement in data.aws_iam_policy_document.invoke.statement : statement if length(statement.condition) > 0]) == 2
    error_message = "Each inference profile must have its own conditioned statement for its foundation models."
  }

  assert {
    condition = alltrue([
      for statement in data.aws_iam_policy_document.invoke.statement :
      toset(statement.resources) == toset(lookup({
        "arn:aws:bedrock:us-east-1:111111111111:inference-profile/us.anthropic.claude-sonnet-4-6" = [
          "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-6",
          "arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-sonnet-4-6",
          "arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-sonnet-4-6",
        ]
        "arn:aws:bedrock:us-east-1:111111111111:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0" = [
          "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0",
          "arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0",
          "arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0",
        ]
      }, one(one(statement.condition).values), []))
      if length(statement.condition) > 0
    ])
    error_message = "Each profile's foundation models must be conditioned on that profile's ARN, and only that profile's."
  }
}

# ConverseStream and InvokeModelWithResponseStream need the streaming action.
run "streaming_is_opt_in" {
  command = plan

  variables {
    allow_streaming = true
  }

  assert {
    condition = alltrue([
      for statement in data.aws_iam_policy_document.invoke.statement :
      toset(statement.actions) == toset(["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"])
    ])
    error_message = "With allow_streaming, every statement must grant bedrock:InvokeModel and bedrock:InvokeModelWithResponseStream."
  }
}

run "service_included_in_name" {
  command = plan

  variables {
    service = "api"
  }

  assert {
    condition     = aws_iam_policy.this.name == "example-test-api-bedrock"
    error_message = "The policy name must include the service when one is set."
  }
}

run "inference_profile_ids_require_profile_prefix" {
  command = plan

  variables {
    inference_profile_ids = ["anthropic.claude-sonnet-4-6"]
  }

  expect_failures = [var.inference_profile_ids]
}
