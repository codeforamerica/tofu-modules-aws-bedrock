variable "allow_streaming" {
  type        = bool
  description = <<-EOT
    Also grant bedrock:InvokeModelWithResponseStream, which ConverseStream and
    InvokeModelWithResponseStream require.
    EOT
  default     = false
}

variable "environment" {
  type        = string
  description = "Environment for the deployment."
  default     = "dev"
}

variable "foundation_model_ids" {
  type        = list(string)
  description = <<-EOT
    Foundation model IDs the principal may invoke directly in the provider's
    region, such as "amazon.nova-lite-v1:0". Each model must support
    on-demand inference; use inference_profile_ids for models that can only be
    reached through a cross-region inference profile.
    EOT
  default     = []

  validation {
    condition = alltrue([
      for id in var.foundation_model_ids :
      !can(regex("^(us|us-gov|eu|apac|global)\\.", id))
    ])
    error_message = "Foundation model IDs must not start with a profile prefix; use inference_profile_ids for cross-region inference profiles."
  }
}

variable "inference_profile_ids" {
  type        = list(string)
  description = <<-EOT
    Cross-region inference profile IDs the principal may invoke, such as
    "us.anthropic.claude-sonnet-4-6". The profile's foundation models may only
    be invoked through the profile.
    EOT
  default     = []

  validation {
    condition = alltrue([
      for id in var.inference_profile_ids :
      can(regex("^(us|us-gov|eu|apac|global)\\.", id))
    ])
    error_message = "Inference profile IDs must start with a profile prefix (us., us-gov., eu., apac., or global.)."
  }
}

variable "project" {
  type        = string
  description = "Project that these resources are supporting."
}

variable "service" {
  type        = string
  description = "Optional service that these resources are supporting."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}
