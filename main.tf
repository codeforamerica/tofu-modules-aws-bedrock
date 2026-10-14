resource "aws_iam_policy" "this" {
  name        = "${local.prefix}-bedrock"
  description = "Allow invoking the declared Bedrock models for ${local.prefix}."
  policy      = data.aws_iam_policy_document.invoke.json

  tags = var.tags

  lifecycle {
    precondition {
      condition     = length(var.inference_profile_ids) + length(var.foundation_model_ids) > 0
      error_message = "At least one of inference_profile_ids or foundation_model_ids must be set."
    }
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset(var.role_names)

  role       = each.value
  policy_arn = aws_iam_policy.this.arn
}

resource "aws_iam_user_policy_attachment" "this" {
  for_each = toset(var.user_names)

  user       = each.value
  policy_arn = aws_iam_policy.this.arn
}
