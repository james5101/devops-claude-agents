# IaC Standards

Org-specific standards for the `iac-author` agent. Edit this file to encode your naming conventions,
required tags, internal module sources, and forbidden patterns. The `/iac-author` command reads this
file at invocation time and passes it verbatim to the generation subagent.

Leave a section blank or delete it if it does not apply — the agent will fall back to sensible defaults.

---

## Naming conventions

<!--
Describe how resources, modules, variables, and files should be named.

Examples:
  Resource names:   <env>-<team>-<component>  (e.g. prod-platform-eks)
  Module names:     <team>-<resource>          (e.g. platform-vpc)
  Variable names:   snake_case
  Local names:      snake_case, prefixed with the resource type where ambiguous
-->

- Resource names: <!-- e.g. `<env>-<team>-<component>` -->
- Module names: <!-- e.g. `<team>-<resource>` -->
- S3 bucket names: <!-- e.g. `<org>-<env>-<purpose>` (must be globally unique) -->
- IAM role names: <!-- e.g. `<env>-<service>-role` -->
- Security group names: <!-- e.g. `<env>-<component>-sg` -->
- Tag key casing: <!-- e.g. PascalCase / snake_case / kebab-case -->

---

## Required tags

<!--
List every tag that must appear on all taggable resources.
Format: TagKey = <description or allowed values>

Examples:
  Environment   = dev | staging | prod
  Team          = platform | data | payments
  CostCenter    = <cost centre code>
  ManagedBy     = terraform
  Owner         = <team email>
-->

| Tag key | Allowed values / description |
|---|---|
| Environment | dev \| staging \| prod |
| ManagedBy | terraform |
| <!-- Team --> | <!-- platform \| data \| payments --> |
| <!-- CostCenter --> | <!-- cost centre code --> |
| <!-- Owner --> | <!-- team email or Slack handle --> |

---

## Internal module registry (MCP)

<!--
The iac-author subagent will attempt to query your internal Terraform module registry
via an MCP server named `terraform-registry`. Configure that server in .mcp.json or
via `claude mcp add`.

Document your module registry here so the agent knows what to expect, and so team
members know what's available without running a query.

Format:
  source: <registry source string>
  description: <what this module provisions>
  inputs: <key inputs to be aware of>
-->

### MCP server configuration

```json
{
  "mcpServers": {
    "terraform-registry": {
      "command": "<!-- command to start your MCP server -->",
      "args": []
    }
  }
}
```

Add this block to `.mcp.json` at the repo root once your MCP server is built.
The `iac-author` subagent will attempt to call `list_modules`, `get_module_schema`,
and `get_module_example` against this server. If the server is not present, it falls
back to the public registry modules listed in the next section.

### Known internal modules

<!--
Document internal modules here as a fallback reference — the agent will use this list
if the MCP server is unavailable or doesn't return results for a resource type.
-->

| Source | Description |
|---|---|
| <!-- `app.terraform.io/<org>/vpc/aws` --> | <!-- Opinionated VPC with 3-AZ subnets and NAT --> |
| <!-- `app.terraform.io/<org>/eks/aws` --> | <!-- Private EKS cluster with IRSA and managed node groups --> |
| <!-- `app.terraform.io/<org>/rds/aws` --> | <!-- RDS with encryption, parameter group, and subnet group --> |

---

## Approved public registry modules

<!--
When no internal module covers the resource type, the agent will fall back to public
registry modules. List your approved public modules here so the agent doesn't pick
arbitrary community modules.

Format: source → version constraint → notes
-->

| Resource type | Approved source | Version |
|---|---|---|
| AWS VPC | `terraform-aws-modules/vpc/aws` | `~> 5.0` |
| AWS EKS | `terraform-aws-modules/eks/aws` | `~> 20.0` |
| AWS RDS | `terraform-aws-modules/rds/aws` | `~> 6.0` |
| AWS S3 bucket | `terraform-aws-modules/s3-bucket/aws` | `~> 4.0` |
| AWS IAM | `terraform-aws-modules/iam/aws` | `~> 5.0` |
| <!-- Azure AKS --> | <!-- `Azure/aks/azurerm` --> | <!-- `~> 9.0` --> |
| <!-- GKE --> | <!-- `terraform-google-modules/kubernetes-engine/google` --> | <!-- `~> 31.0` --> |

---

## Forbidden patterns

<!--
Patterns the agent must never generate, regardless of what the user asks for.
The agent will add a WARNING comment if a user request requires violating one of these.

Examples:
  - No public S3 buckets (block_public_acls must always be true)
  - No security group rules with 0.0.0.0/0 ingress on port 22 or 3389
  - No IAM policies with Action: "*" and Resource: "*"
  - No skip_final_snapshot = true on RDS in prod
  - No force_destroy = true on S3 in prod
-->

- No hardcoded credentials, passwords, or API keys in any `.tf` file
- No `"Action": "*"` with `"Resource": "*"` in IAM policies without an explanatory comment
- <!-- Add your org-specific forbidden patterns here -->

---

## Backend configuration

<!--
Specify the Terraform backend to use. The agent will include this in generated root modules.
Leave blank to omit backend configuration (user configures it separately).

Example for S3:
  backend "s3" {
    bucket         = "<your-state-bucket>"
    key            = "<component>/<env>/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "<your-lock-table>"
  }
-->

<!-- Paste your backend block here, or leave blank -->

---

## Default provider configuration

<!--
Provider-level defaults to apply to all generated configs.
Common examples: default region, default tags (AWS provider default_tags),
required provider version constraints.
-->

### AWS

```hcl
# Uncomment and fill in your defaults
# provider "aws" {
#   region = "us-east-1"
#
#   default_tags {
#     tags = {
#       ManagedBy   = "terraform"
#       # Add org-wide default tags here
#     }
#   }
# }
```

### Azure

```hcl
# provider "azurerm" {
#   features {}
#   subscription_id = var.subscription_id
# }
```

### GCP

```hcl
# provider "google" {
#   project = var.project_id
#   region  = var.region
# }
```

---

## Environment-specific overrides

<!--
Override sizing or behaviour for specific environments.
The agent uses these to set variable defaults in generated code.

Format: free text or a table per cloud.
-->

<!-- Example:
- prod: RDS multi-AZ enabled, deletion_protection = true, skip_final_snapshot = false
- staging: single-AZ, deletion_protection = false
- dev: smallest viable instance, skip_final_snapshot = true
-->
