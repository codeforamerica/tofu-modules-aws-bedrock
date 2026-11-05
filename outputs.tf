output "inference_profile_arns" {
  description = "Map of each granted inference profile ID to its ARN."
  value       = local.inference_profile_arns
}

output "model_arns" {
  description = "ARNs of every foundation model the policy grants."
  value = distinct(concat(
    values(local.foundation_model_arns),
    flatten(values(local.inference_profile_model_arns)),
  ))
}

output "policy_arn" {
  description = "ARN of the Bedrock invoke policy, for attaching to a role or user."
  value       = aws_iam_policy.this.arn
}

output "policy_json" {
  description = "JSON of the Bedrock invoke policy document."
  value       = data.aws_iam_policy_document.invoke.json
}

output "policy_name" {
  description = "Name of the Bedrock invoke policy."
  value       = aws_iam_policy.this.name
}

output "security_group_id" {
  description = "ID of the VPC endpoint's security group, or null when no endpoint is created."
  value       = try(aws_security_group.endpoint["this"].id, null)
}

output "vpc_endpoint_id" {
  description = "ID of the Bedrock Runtime VPC endpoint, or null when no endpoint is created."
  value       = try(aws_vpc_endpoint.bedrock_runtime["this"].id, null)
}
