data "aws_bedrock_foundation_model" "this" {
  for_each = toset(var.foundation_model_ids)

  model_id = each.value

  lifecycle {
    postcondition {
      condition     = contains(self.inference_types_supported, "ON_DEMAND")
      error_message = "Foundation model \"${each.value}\" does not support on-demand inference in this region. Use its cross-region inference profile in inference_profile_ids instead."
    }
  }
}

data "aws_bedrock_inference_profile" "this" {
  for_each = toset(var.inference_profile_ids)

  inference_profile_id = each.value
}

# Limits the Bedrock Runtime endpoint to the IAM policy's statements, for the
# given principals only. Principals are matched by ARN in a condition: a named
# role principal is stored as the role's unique ID, so recreating the role
# would silently lock it out while the policy text stayed unchanged.
data "aws_iam_policy_document" "endpoint" {
  for_each = var.create_vpc_endpoint ? toset(["this"]) : toset([])

  dynamic "statement" {
    for_each = local.policy_statements

    content {
      sid       = statement.value.sid
      actions   = local.actions
      resources = statement.value.resources

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "StringEquals"
        variable = "aws:PrincipalArn"
        values   = var.endpoint_principal_arns
      }

      dynamic "condition" {
        for_each = statement.value.inference_profile_arn != null ? [statement.value.inference_profile_arn] : []

        content {
          test     = "StringEquals"
          variable = "bedrock:InferenceProfileArn"
          values   = [condition.value]
        }
      }
    }
  }
}

data "aws_iam_policy_document" "invoke" {
  dynamic "statement" {
    for_each = local.policy_statements

    content {
      sid       = statement.value.sid
      actions   = local.actions
      resources = statement.value.resources

      dynamic "condition" {
        for_each = statement.value.inference_profile_arn != null ? [statement.value.inference_profile_arn] : []

        content {
          test     = "StringEquals"
          variable = "bedrock:InferenceProfileArn"
          values   = [condition.value]
        }
      }
    }
  }
}

data "aws_region" "current" {}
