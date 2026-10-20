# OpenTofu AWS Bedrock Module – Architecture Decision Record (ADR)
## ADR-001: Bedrock Runtime Access Module

Status: Proposed

Date: 2026-10-14

Author: Morgan Todd

Decision Owners: _TBD_

---

### 1. Context

Several Code for America applications call Amazon Bedrock at runtime, and each
infrastructure repository grants that access in its own way:

- **cj-petition-generator** calls the `bedrock-runtime` `Converse` operation from a
  Fargate task, using its task role. Its infrastructure
  ([cj-petition-generator-infra ADR-004][cj-adr-004]) looks up the configured
  cross-region inference profile with the `aws_bedrock_inference_profile` data
  source. It grants `bedrock:InvokeModel` on the profile, and on the profile's
  foundation models only under a `bedrock:InferenceProfileArn` condition. It also
  creates a `bedrock-runtime` interface VPC endpoint whose policy is limited to the
  task role.
- **vita-min** (GetYourRefund) calls `InvokeModel` with the US cross-region
  inference profile `us.anthropic.claude-haiku-4-5-20251001-v1:0`
  ([`bedrock_doc_screener.rb`][vita-min-screener]). It runs on Aptible, which has no
  instance or task role, so the SDK's default credential chain resolves to IAM user
  access keys supplied as environment variables. No OpenTofu configuration currently
  manages that user's Bedrock permissions.
- **shared-services-infra** lets a hosted service opt into Bedrock in its app spec
  ([`tofu/modules/app/bedrock.tf`][shared-bedrock]). It builds ARNs from strings:
  the inference profile in the current region, and the foundation model with a
  wildcard region and no condition. It grants both `bedrock:InvokeModel` and
  `bedrock:InvokeModelWithResponseStream`.

These implementations have drifted apart. The differences matter for security:

- The shared-services pattern lets a principal invoke the foundation model directly,
  in any region, not only through the profile.
- cj-petition-generator-infra previously granted a wildcard foundation-model ARN that
  did not cover the inference profile at all. This surfaced only at runtime as
  `AccessDeniedException`.
- None of the three repositories can be reused by another project without copying
  code.

The two runtime usage patterns that must be supported are **Converse** and
**InvokeModel**. Both are authorized by the same IAM action. Their streaming variants
use a second action:

| API                             | IAM action                              |
|---------------------------------|-----------------------------------------|
| `Converse`                      | `bedrock:InvokeModel`                   |
| `InvokeModel`                   | `bedrock:InvokeModel`                   |
| `ConverseStream`                | `bedrock:InvokeModelWithResponseStream` |
| `InvokeModelWithResponseStream` | `bedrock:InvokeModelWithResponseStream` |

---

### 2. Decisions

#### 2.1 A standalone module that produces a policy; the caller owns the principal

`tofu-modules-aws-bedrock` creates a single customer-managed IAM policy, named
`<project>-<environment>[-<service>]-bedrock`, and outputs its ARN. The module does
**not** create IAM roles, IAM users, access keys, or Bedrock API keys.

The calling configuration attaches the policy to its own principal. It can do this
with the module's optional `role_names` and `user_names` inputs, or through another
module's input, for example `task_policies` on `tofu-modules-aws-fargate-service`.
This supports both principals in use today:

- **Role-based workloads** (Fargate tasks in cj-petition-generator and
  shared-services) attach the policy to the task role.
- **Key-based workloads** (vita-min on Aptible) attach the policy to the existing
  IAM user whose keys the application already uses.

Keeping credential creation out of the module keeps long-lived secret material out
of OpenTofu state. It also leaves each project's credential lifecycle (rotation,
ownership) where it is today.

#### 2.2 Strict cross-region inference profile permissions

For each inference profile ID, the module looks up the profile with the
`aws_bedrock_inference_profile` data source. The policy then contains:

1. One statement granting the actions on every profile ARN, with no condition.
2. One statement **per profile** granting the actions on exactly the foundation-model
   ARNs that the profile routes to. It is conditioned on `bedrock:InferenceProfileArn`
   equalling that profile's ARN.

The foundation models behind a profile can therefore only be invoked through that
profile, never directly. No wildcard model or region ARNs are granted. This is the
pattern established in [cj-petition-generator-infra ADR-004 §2.3][cj-adr-004] and
recommended in AWS's [inference profile prerequisites][aws-profile-prereq].

#### 2.3 The model IDs are the single source of truth for IAM

Callers declare which models they use with two inputs:

- `inference_profile_ids`: cross-region inference profile IDs, such as
  `us.anthropic.claude-sonnet-4-6`. These must start with a profile prefix
  (`us.`, `us-gov.`, `eu.`, `apac.`, or `global.`).
- `foundation_model_ids`: foundation models invoked directly in the provider's
  region. These must not start with a profile prefix.

At least one ID is required. Each foundation model is looked up with the
`aws_bedrock_foundation_model` data source. A precondition requires the model to
support `ON_DEMAND` inference, so a model that is reachable only through an inference
profile (such as recent Anthropic models) fails at plan time. This generalizes the
shared-services check that rejects bare `anthropic.*` IDs.

The policy's ARNs are derived from these lookups, not maintained as a separate list.
An invalid or unavailable ID fails at **plan** time instead of surfacing as
`AccessDeniedException` at runtime. Changing a model changes IAM in the same plan.

The module outputs the resolved profile and model ARNs. Callers should pass the same
IDs to the application (for example as `BEDROCK_MODEL_ID`), so the model the
application uses and the model IAM allows cannot diverge.

#### 2.4 Least-privilege actions; streaming is opt-in

The policy grants only `bedrock:InvokeModel` by default. This covers both `Converse`
and `InvokeModel`, which are the only APIs cj-petition-generator and vita-min call.

Setting `allow_streaming = true` adds `bedrock:InvokeModelWithResponseStream` for
applications that use `ConverseStream` or `InvokeModelWithResponseStream`. No
control-plane actions are granted.

#### 2.5 Optional `bedrock-runtime` interface VPC endpoint

When `create_vpc_endpoint = true`, the module creates:

- an **Interface VPC endpoint** for `com.amazonaws.<region>.bedrock-runtime` in the
  given subnets, with private DNS enabled, so SDKs reach it with no application
  changes;
- a **security group** that admits HTTPS (443) only from the given security groups,
  with no CIDR-based rules;
- an **endpoint policy** that allows the same actions on the same resources as the
  IAM policy. It applies only to the given principals, matched with an
  `aws:PrincipalArn` condition. A named role principal would be stored as the role's
  unique ID, so recreating the role would silently lock it out of the endpoint
  ([cj-petition-generator-infra ADR-004 §2.2][cj-adr-004]).

The endpoint is off by default. Workloads outside a VPC (vita-min on Aptible) cannot
use it. Projects whose networking layer already creates a `bedrock-runtime` endpoint
(shared-services, via `tofu-modules-aws-vpc`'s `additional_interface_endpoints`)
should not create a second one.

#### 2.6 Region comes from the provider

Inference profile ARNs are regional. The module uses the region of the AWS provider
it is given, which must be the region the application's Bedrock client calls.
Cross-region routing to the profile's other regions happens on the AWS network and
is covered by §2.2.

#### 2.7 Policies are written as `aws_iam_policy_document` data sources

CfA's OpenTofu conventions prefer YAML templates for policies. This module uses
`aws_iam_policy_document` instead, for two reasons:

- The per-profile statements in §2.2 are generated dynamically, which reads more
  clearly as a `dynamic "statement"` block than as loops in a template.
- Tests can assert on individual statements, actions, resources, and conditions, as
  the cj-petition-generator-infra tests do.

#### 2.8 Plan-only tests against a mocked provider

The module is tested with `tofu test`. The tests use plan-only `run` blocks against a
mocked AWS provider, with data-source overrides describing realistic inference
profiles. They need no AWS credentials. They assert:

- the actions granted;
- that no wildcards appear;
- that only profile ARNs are unconditioned;
- the per-profile conditions;
- the endpoint's security group and policy;
- the input validations.

#### 2.9 Account-level Bedrock settings are out of scope

These settings apply to an AWS account as a whole, or are not needed by current
consumers. The module does not manage them:

- **Model access.** Anthropic models require a one-time use-case submission per
  account.
- **Model invocation logging.** Enabling it persists prompts and responses, which
  for CfA applications contain PII. Whether to enable it is a per-account decision.
- **Service quotas** for tokens and requests per minute.
- **Bedrock API keys.**
- **Guardrails, application inference profiles, provisioned throughput, and custom
  models.** No current consumer uses these; they can be added in a later version if
  needed.

---

### 3. Consequences

**Positive:**

- One reviewed implementation of Bedrock runtime access replaces three divergent
  ones.
- Every principal is limited to the declared models, invoked through their declared
  profiles, with no wildcard ARNs.
- Mistyped or unavailable model IDs fail at plan time.
- The module supports both role-based (Fargate) and key-based (Aptible) workloads
  without managing credentials itself.

**Negative / Risks:**

- **Plan-time AWS lookups.** The data sources in §2.2 and §2.3 call Bedrock during
  plan. Whoever runs `tofu plan` (a developer or a CI role) needs
  `bedrock:GetInferenceProfile` and `bedrock:GetFoundationModel`. The shared-services
  pattern needs neither.
- **Profile changes surface in plans.** If AWS adds a region to an inference profile,
  the next plan shows an IAM change. This is intended: it should be reviewed, not
  ignored.
- **Stricter than shared-services today.** Moving shared-services services onto the
  module removes their direct and wildcard-region foundation-model access. Any
  service that invokes a foundation model directly rather than through its profile
  would break.
- **Static keys remain for Aptible workloads.** vita-min's IAM user and access keys
  continue to be created and rotated outside OpenTofu. The module narrows what those
  keys can do in Bedrock, but does not address their lifecycle.
- **Convention deviation.** Policies are not YAML templates (§2.7).

**Future work:**

- Migrate cj-petition-generator-infra, shared-services-infra, and vita-min's
  infrastructure onto the module.
- Add `tofu test` to the repository's pull request workflow.
- Add guardrail support (`bedrock:ApplyGuardrail`) when a consumer needs it.

---

### 4. Assumptions

- vita-min's production credentials are IAM user access keys set in Aptible's
  configuration. This is inferred from the application's use of the SDK default
  credential chain on Aptible; the configuration itself was not reviewed.
- Everything here assumes the AWS provider is v6 or later, and OpenTofu 1.11 or later.

---

### 5. Sources

- [cj-petition-generator-infra ADR-004: Bedrock Runtime Infrastructure][cj-adr-004]
- [shared-services-infra: app module Bedrock policy][shared-bedrock]
- [vita-min: `BedrockDocScreener`][vita-min-screener]
- [Amazon Bedrock: Prerequisites for inference profiles][aws-profile-prereq]
- [Service Authorization Reference: Actions, resources, and condition keys for Amazon Bedrock][aws-bedrock-iam]

[aws-bedrock-iam]: https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonbedrock.html
[aws-profile-prereq]: https://docs.aws.amazon.com/bedrock/latest/userguide/inference-profiles-prereq.html
[cj-adr-004]: https://github.com/codeforamerica/cj-petition-generator-infra/blob/main/docs/adr/adr-004_bedrock-runtime-infrastructure.md
[shared-bedrock]: https://github.com/codeforamerica/shared-services-infra/blob/main/tofu/modules/app/bedrock.tf
[vita-min-screener]: https://github.com/codeforamerica/vita-min/blob/main/app/services/bedrock_doc_screener.rb
