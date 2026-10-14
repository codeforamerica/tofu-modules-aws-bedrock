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

# Grants the inference profiles and in-region foundation models directly, and
# each profile's foundation models only when invoked through that profile.
data "aws_iam_policy_document" "invoke" {
  dynamic "statement" {
    for_each = length(local.foundation_model_arns) > 0 ? ["this"] : []

    content {
      sid       = "InvokeFoundationModels"
      actions   = local.actions
      resources = values(local.foundation_model_arns)
    }
  }

  dynamic "statement" {
    for_each = length(local.inference_profile_arns) > 0 ? ["this"] : []

    content {
      sid       = "InvokeInferenceProfiles"
      actions   = local.actions
      resources = values(local.inference_profile_arns)
    }
  }

  dynamic "statement" {
    for_each = local.inference_profile_model_arns

    content {
      sid       = "InvokeModelsVia${replace(statement.key, "/[^0-9A-Za-z]/", "")}"
      actions   = local.actions
      resources = statement.value

      condition {
        test     = "StringEquals"
        variable = "bedrock:InferenceProfileArn"
        values   = [local.inference_profile_arns[statement.key]]
      }
    }
  }
}
