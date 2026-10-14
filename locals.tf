locals {
  # Converse and InvokeModel are both authorized by bedrock:InvokeModel. Their
  # streaming variants also need bedrock:InvokeModelWithResponseStream.
  actions = compact([
    "bedrock:InvokeModel",
    var.allow_streaming ? "bedrock:InvokeModelWithResponseStream" : null,
  ])

  foundation_model_arns = {
    for id, model in data.aws_bedrock_foundation_model.this :
    id => model.model_arn
  }

  inference_profile_arns = {
    for id, profile in data.aws_bedrock_inference_profile.this :
    id => profile.inference_profile_arn
  }

  # The foundation models each inference profile routes to, across every
  # region the profile covers.
  inference_profile_model_arns = {
    for id, profile in data.aws_bedrock_inference_profile.this :
    id => [for model in profile.models : model.model_arn]
  }

  prefix = join("-", compact([var.project, var.environment, var.service]))
}
