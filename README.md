# AWS Bedrock Module

[![GitHub Release][badge-release]][latest-release]

This module grants least-privilege access to the Amazon Bedrock runtime. It
creates an IAM policy that allows invoking only the declared models, for
attaching to the role or user your application runs as. Optionally, it creates
a Bedrock Runtime interface VPC endpoint limited to the same models and
principals.

The module supports the `Converse` and `InvokeModel` APIs, and optionally their
streaming variants. It does not create IAM roles, users, or access keys.

## Usage

Add this module to your `main.tf` (or appropriate) file and configure the inputs
to match your desired configuration. For example, to grant a Fargate service
access to a model through its task role, over a private VPC endpoint:

```hcl
module "bedrock" {
  source = "github.com/codeforamerica/tofu-modules-aws-bedrock?ref=1.0.0"

  project     = "my-project"
  environment = "staging"

  inference_profile_ids = ["us.anthropic.claude-sonnet-4-6"]

  create_vpc_endpoint                 = true
  vpc_id                              = module.vpc.vpc_id
  subnet_ids                          = module.vpc.private_subnets
  endpoint_allowed_security_group_ids = [module.service.security_group_id]
  endpoint_principal_arns             = [module.service.task_role_arn]
}

module "service" {
  source = "github.com/codeforamerica/tofu-modules-aws-fargate-service?ref=1.14.0"

  # ...

  task_policies = [module.bedrock.policy_arn]

  environment_variables = {
    BEDROCK_MODEL_ID = "us.anthropic.claude-sonnet-4-6"
  }
}
```

Make sure you re-run `tofu init` after adding the module to your configuration.

```bash
tofu init
tofu plan
```

To update the source for this module, pass `-upgrade` to `tofu init`:

```bash
tofu init -upgrade
```

### Supported APIs

By default, the policy grants only `bedrock:InvokeModel`. Set `allow_streaming`
to `true` if your application uses a streaming API.

| API                             | IAM action                              | Requires `allow_streaming` |
|---------------------------------|-----------------------------------------|----------------------------|
| `Converse`                      | `bedrock:InvokeModel`                   | no                         |
| `InvokeModel`                   | `bedrock:InvokeModel`                   | no                         |
| `ConverseStream`                | `bedrock:InvokeModelWithResponseStream` | yes                        |
| `InvokeModelWithResponseStream` | `bedrock:InvokeModelWithResponseStream` | yes                        |

### Inference profiles and foundation models

Declare the models your application invokes with `inference_profile_ids`,
`foundation_model_ids`, or both. At least one is required.

- **Inference profiles** (`inference_profile_ids`) are cross-region inference
  profile IDs, such as `us.anthropic.claude-sonnet-4-6`. The policy grants the
  profile, and grants the foundation models the profile routes to only when
  they're invoked through that profile. Recent Anthropic models can only be
  invoked this way.
- **Foundation models** (`foundation_model_ids`) are models invoked directly in
  the provider's region, such as `amazon.nova-lite-v1:0`. Each must support
  on-demand inference in that region.

Each ID is looked up in Bedrock during `tofu plan`, so a mistyped or
unavailable model fails the plan rather than failing at runtime with an
`AccessDeniedException`. If AWS adds a region to an inference profile, the next
plan will show a change to the policy.

> [!IMPORTANT]
> The module uses the region of the AWS provider it's given. This must be the
> region your application's Bedrock client calls.

Pass the same model ID to your application, as `BEDROCK_MODEL_ID` in the example
above, so the model it calls is always the model it's allowed to call.

### Applications hosted outside AWS

Applications hosted outside AWS, such as on Aptible, typically authenticate
with an IAM user's access keys. Use `user_names` to attach the policy to an
existing user. The module doesn't create or manage the user or its keys.

```hcl
module "bedrock" {
  source = "github.com/codeforamerica/tofu-modules-aws-bedrock?ref=1.0.0"

  project     = "my-project"
  environment = "production"

  inference_profile_ids = ["us.anthropic.claude-haiku-4-5-20251001-v1:0"]
  user_names            = ["my-project-production"]
}
```

Similarly, use `role_names` to attach the policy to an existing role. Names in
`role_names` and `user_names` must be known at plan time; if the role is created
in the same configuration, pass `policy_arn` to it instead, as in the Fargate
example above.

### VPC endpoint

Set `create_vpc_endpoint` to `true` to keep Bedrock traffic from workloads in a
VPC off the public internet. The module creates:

- An interface endpoint for `bedrock-runtime` with private DNS enabled, so SDKs
  use it without configuration changes
- A security group that admits HTTPS only from
  `endpoint_allowed_security_group_ids`
- An endpoint policy that allows only the declared models, and only for
  `endpoint_principal_arns`

Don't enable this if your VPC already has a `bedrock-runtime` endpoint, for
example one created by the [VPC module][vpc-module]'s
`additional_interface_endpoints`. A VPC can only have one endpoint with private
DNS for each service.

### Prerequisites

The following apply to an AWS account as a whole and aren't managed by this
module:

- **Model access.** Anthropic models require a one-time use case submission for
  each account.
- **Model invocation logging.** Enabling it stores prompts and responses, which
  may contain sensitive data.
- **Service quotas.** Tokens and requests per minute are limited per account
  and region.

Whoever runs `tofu plan`, including CI, needs `bedrock:GetInferenceProfile` and
`bedrock:GetFoundationModel` to look up the declared models.

## Inputs

| Name                                | Description                                                                                                               | Type           | Default | Required    |
|-------------------------------------|---------------------------------------------------------------------------------------------------------------------------|----------------|---------|-------------|
| project                             | Project that these resources are supporting.                                                                              | `string`       | n/a     | yes         |
| endpoint_allowed_security_group_ids | Security groups allowed to reach the VPC endpoint over HTTPS. Required when `create_vpc_endpoint` is `true`.              | `list(string)` | `[]`    | conditional |
| endpoint_principal_arns             | ARNs of the IAM principals allowed to use the VPC endpoint. Required when `create_vpc_endpoint` is `true`.                | `list(string)` | `[]`    | conditional |
| foundation_model_ids                | Foundation model IDs to allow invoking directly in the provider's region. At least one model or profile is required.      | `list(string)` | `[]`    | conditional |
| inference_profile_ids               | Cross-region inference profile IDs to allow invoking. At least one model or profile is required.                          | `list(string)` | `[]`    | conditional |
| subnet_ids                          | Subnets to place the VPC endpoint in. Required when `create_vpc_endpoint` is `true`.                                      | `list(string)` | `[]`    | conditional |
| vpc_id                              | VPC to create the VPC endpoint in. Required when `create_vpc_endpoint` is `true`.                                         | `string`       | `null`  | conditional |
| allow_streaming                     | Also allow `bedrock:InvokeModelWithResponseStream`, for `ConverseStream` and `InvokeModelWithResponseStream`.             | `bool`         | `false` | no          |
| create_vpc_endpoint                 | Create a Bedrock Runtime interface VPC endpoint.                                                                          | `bool`         | `false` | no          |
| environment                         | Environment for the deployment.                                                                                           | `string`       | `"dev"` | no          |
| role_names                          | Names of existing IAM roles to attach the policy to. Must be known at plan time.                                          | `list(string)` | `[]`    | no          |
| service                             | Optional service that these resources are supporting.                                                                     | `string`       | `null`  | no          |
| tags                                | Tags to apply to all resources.                                                                                           | `map(string)`  | `{}`    | no          |
| user_names                          | Names of existing IAM users to attach the policy to. Must be known at plan time.                                          | `list(string)` | `[]`    | no          |

## Outputs

| Name                   | Description                                                                   | Type           |
|------------------------|-------------------------------------------------------------------------------|----------------|
| inference_profile_arns | Map of each granted inference profile ID to its ARN.                          | `map(string)`  |
| model_arns             | ARNs of every foundation model the policy grants.                             | `list(string)` |
| policy_arn             | ARN of the Bedrock invoke policy, for attaching to a role or user.            | `string`       |
| policy_json            | JSON of the Bedrock invoke policy document.                                   | `string`       |
| policy_name            | Name of the Bedrock invoke policy.                                            | `string`       |
| security_group_id      | ID of the VPC endpoint's security group, or `null` if no endpoint is created. | `string`       |
| vpc_endpoint_id        | ID of the Bedrock Runtime VPC endpoint, or `null` if no endpoint is created.  | `string`       |

## Contributing

This repository uses [pre-commit](https://pre-commit.com) to enforce code
style checks before each commit. Install it once after cloning:

**1. Install pre-commit**

```sh
brew install pre-commit
```

**2. Install the git hook**

```sh
pre-commit install
```

This symlinks the hook into `.git/hooks/pre-commit`. The checks will now run
automatically on every `git commit`. To run them manually against all files:

```sh
pre-commit run --all-files
```

The module's tests run against a mocked AWS provider, so they don't need AWS
credentials:

```sh
tofu init
tofu test
```

Follow the [contributing guidelines][contributing] to contribute to this
repository.

[badge-release]: https://img.shields.io/github/v/release/codeforamerica/tofu-modules-aws-bedrock?logo=github&label=Latest%20Release
[contributing]: CONTRIBUTING.md
[latest-release]: https://github.com/codeforamerica/tofu-modules-aws-bedrock/releases/latest
[vpc-module]: https://github.com/codeforamerica/tofu-modules-aws-vpc
