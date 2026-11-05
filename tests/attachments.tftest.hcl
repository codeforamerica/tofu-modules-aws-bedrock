# Plan-only tests for attaching the policy to existing roles and users.
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

override_data {
  target = data.aws_bedrock_inference_profile.this["us.anthropic.claude-haiku-4-5-20251001-v1:0"]
  values = {
    inference_profile_arn = "arn:aws:bedrock:us-east-1:111111111111:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0"
    models = [
      { model_arn = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0" },
    ]
  }
}

variables {
  project               = "example"
  environment           = "test"
  inference_profile_ids = ["us.anthropic.claude-haiku-4-5-20251001-v1:0"]
}

run "no_attachments_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 0
    error_message = "No role attachments may be created unless role_names is set."
  }

  assert {
    condition     = length(aws_iam_user_policy_attachment.this) == 0
    error_message = "No user attachments may be created unless user_names is set."
  }
}

# For example, an ECS task role.
run "attaches_to_roles" {
  command = plan

  variables {
    role_names = ["example-test-task", "example-test-worker"]
  }

  assert {
    condition     = toset(keys(aws_iam_role_policy_attachment.this)) == toset(["example-test-task", "example-test-worker"])
    error_message = "The policy must be attached to each role in role_names."
  }

  assert {
    condition = alltrue([
      for name, attachment in aws_iam_role_policy_attachment.this :
      attachment.role == name && attachment.policy_arn == "arn:aws:iam::111111111111:policy/example-test-bedrock"
    ])
    error_message = "Each role attachment must attach this module's policy to the named role."
  }
}

# For example, the IAM user whose access keys an Aptible app uses.
run "attaches_to_users" {
  command = plan

  variables {
    user_names = ["example-test-app"]
  }

  assert {
    condition     = toset(keys(aws_iam_user_policy_attachment.this)) == toset(["example-test-app"])
    error_message = "The policy must be attached to each user in user_names."
  }

  assert {
    condition = alltrue([
      for name, attachment in aws_iam_user_policy_attachment.this :
      attachment.user == name && attachment.policy_arn == "arn:aws:iam::111111111111:policy/example-test-bedrock"
    ])
    error_message = "Each user attachment must attach this module's policy to the named user."
  }
}
