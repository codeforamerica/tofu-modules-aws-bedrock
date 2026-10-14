variable "allow_streaming" {
  type        = bool
  description = <<-EOT
    Also grant bedrock:InvokeModelWithResponseStream, which ConverseStream and
    InvokeModelWithResponseStream require.
    EOT
  default     = false
}

variable "create_vpc_endpoint" {
  type        = bool
  description = <<-EOT
    Create a Bedrock Runtime interface VPC endpoint, limited to the declared
    models and to endpoint_principal_arns. Requires vpc_id, subnet_ids,
    endpoint_allowed_security_group_ids, and endpoint_principal_arns.
    EOT
  default     = false
}

variable "endpoint_allowed_security_group_ids" {
  type        = list(string)
  description = "Security groups allowed to reach the VPC endpoint over HTTPS, such as an ECS task's security group."
  default     = []
}

variable "endpoint_principal_arns" {
  type        = list(string)
  description = "ARNs of the IAM principals allowed to use the VPC endpoint, such as an ECS task role."
  default     = []
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

variable "role_names" {
  type        = list(string)
  description = <<-EOT
    Names of existing IAM roles to attach the policy to, such as an ECS task
    role. Names must be known at plan time.
    EOT
  default     = []
}

variable "service" {
  type        = string
  description = "Optional service that these resources are supporting."
  default     = null
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets to place the VPC endpoint in, typically the private subnets of the workloads that use it."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}

variable "user_names" {
  type        = list(string)
  description = <<-EOT
    Names of existing IAM users to attach the policy to, such as the user whose
    access keys an application hosted outside AWS uses. Names must be known at
    plan time.
    EOT
  default     = []
}

variable "vpc_id" {
  type        = string
  description = "VPC to create the VPC endpoint in."
  default     = null
}
