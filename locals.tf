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

  # Statements shared by the IAM and endpoint policies. Inference profiles and
  # in-region foundation models are granted directly; each profile's
  # foundation models only when invoked through that profile.
  policy_statements = concat(
    length(local.foundation_model_arns) > 0 ? [{
      sid                   = "InvokeFoundationModels"
      resources             = values(local.foundation_model_arns)
      inference_profile_arn = null
    }] : [],
    length(local.inference_profile_arns) > 0 ? [{
      sid                   = "InvokeInferenceProfiles"
      resources             = values(local.inference_profile_arns)
      inference_profile_arn = null
    }] : [],
    [
      for id, arns in local.inference_profile_model_arns : {
        sid                   = "InvokeModelsVia${replace(id, "/[^0-9A-Za-z]/", "")}"
        resources             = arns
        inference_profile_arn = local.inference_profile_arns[id]
      }
    ],
  )

  prefix = join("-", compact([var.project, var.environment, var.service]))
}
