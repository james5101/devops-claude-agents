---
name: terraform-plan-reviewer
description: Review a Terraform plan (pasted as plaintext output of `terraform plan`) and produce a risk-graded analysis covering destructive changes, security posture changes, blast radius, stateful resource risk, and operational impact. Use when the user pastes terraform plan output, asks to review or analyze a plan, or asks "is this safe to apply?" in a Terraform context. Produces an inline risk verdict (SAFE TO APPLY / REVIEW CAREFULLY / HOLD — DESTRUCTIVE) with severity-grouped findings. Does not auto-apply changes.
---

# Terraform plan reviewer

Analyzes the plaintext output of `terraform plan` and produces an inline risk-graded review. Does not apply changes.

## When this skill triggers

- The user pastes text that looks like `terraform plan` output — contains markers like `Terraform will perform the following actions`, `Plan: N to add, N to change, N to destroy`, resource blocks prefixed with `+` / `~` / `-` / `-/+` / `+/-`
- The user asks to review, analyze, check, or audit a Terraform plan
- The user asks "is this safe to apply?" in a Terraform context
- The user references a `.tfplan` file or a saved plan output file and asks for a review

Do NOT trigger for:
- General Terraform authoring questions (no plan output present)
- `terraform apply` output (apply already ran)
- Helm / Kubernetes manifests (different skills cover those)
- Terraform state files without an accompanying plan

## Input

The user provides the plaintext output of `terraform plan` — pasted directly into chat or as a file path. The format is the human-readable terminal output, not JSON.

Key markers to identify terraform plan output:
- `Terraform will perform the following actions`
- Per-resource blocks: `# <resource_type.name> will be created/updated/destroyed/replaced`
- Summary line: `Plan: N to add, N to change, N to destroy.`
- `+` (add), `~` (update in-place), `-` (destroy), `-/+` or `+/-` (replace) prefixes on attributes

If the user references a file, read it with the Read tool before analyzing.

## What to evaluate (six axes — all of them, every time)

### 1. Destructive changes

This is the highest-priority axis. Every `destroy` and every `replace` must be called out explicitly — no exceptions.

**Identify all of:**
- Resources marked `will be destroyed` (`-`) — direct deletes
- Resources marked `must be replaced` (`-/+` or `+/-`) — delete then recreate; the old resource is gone before the new one exists
- Attributes annotated `# forces replacement` — identify which attribute causes it and whether the replacement is avoidable

**Stateful resources — Critical data-loss risk on destroy/replace:**
Flag these resource types at Critical severity when destroyed or replaced:

| Category | Resource types |
|---|---|
| Relational DBs | `aws_db_instance`, `aws_rds_cluster`, `aws_rds_cluster_instance`, `google_sql_database_instance`, `azurerm_postgresql_server`, `azurerm_mysql_server`, `azurerm_mssql_server` |
| NoSQL / Document | `aws_dynamodb_table`, `google_bigtable_instance`, `azurerm_cosmosdb_account` |
| Object storage | `aws_s3_bucket`, `google_storage_bucket`, `azurerm_storage_account` |
| File storage | `aws_efs_file_system`, `aws_fsx_*`, `google_filestore_instance`, `azurerm_storage_share` |
| Block storage | `aws_ebs_volume`, `azurerm_managed_disk`, `google_compute_disk` |
| Caches | `aws_elasticache_cluster`, `aws_elasticache_replication_group`, `google_redis_instance`, `azurerm_redis_cache` |
| Message queues | `aws_sqs_queue`, `google_pubsub_topic`, `google_pubsub_subscription`, `azurerm_servicebus_namespace`, `azurerm_servicebus_queue` |
| Search | `aws_elasticsearch_domain`, `aws_opensearch_domain`, `azurerm_search_service` |
| Secrets stores | `aws_secretsmanager_secret`, `google_secret_manager_secret`, `azurerm_key_vault` |

For stateful replacements: data is permanently lost unless an automated backup or snapshot exists. Flag whether backup/snapshot is visible in the plan.

**Replacement root cause:** When `# forces replacement` appears, assess:
- Is this intentional? (e.g., renaming a resource, changing an immutable tag)
- Could it be avoided with `ignore_changes`, a lifecycle block, or a different attribute value?
- Is there a safer path — `create_before_destroy`, blue/green swap, snapshot + restore?

### 2. Security posture changes

**IAM and permissions:**
- New or modified IAM roles, policies, bindings, attachments: `aws_iam_role`, `aws_iam_policy`, `aws_iam_role_policy`, `aws_iam_role_policy_attachment`, `google_project_iam_binding`, `google_project_iam_member`, `azurerm_role_assignment`, `azurerm_user_assigned_identity`
- `"Action": "*"` or `"Resource": "*"` in inline or managed policy documents — wildcard on sensitive services (`sts:*`, `iam:*`, `s3:*`, `secretsmanager:*`, `kms:*`) is Critical
- Service accounts / managed identities granted broad roles (Owner, Contributor, roles/editor, roles/owner)

**Network security:**
- Security groups and firewall rules: `aws_security_group`, `aws_security_group_rule`, `aws_vpc_security_group_ingress_rule`, `google_compute_firewall`, `azurerm_network_security_group`, `azurerm_network_security_rule`
- Ingress rules with source `0.0.0.0/0` or `::/0` — flag the specific port(s) being opened
- Sensitive ports opened to the internet: 22 (SSH), 3389 (RDP), 5432 (Postgres), 3306 (MySQL), 27017 (Mongo), 6379 (Redis), 9200 (Elasticsearch)

**Public access:**
- S3 becoming public: `block_public_acls = false`, `block_public_policy = false`, `restrict_public_buckets = false`, or `aws_s3_bucket_public_access_block` being destroyed
- GCS becoming public: `predefined_acl = "publicRead"` or `allUsers` / `allAuthenticatedUsers` in IAM bindings
- New load balancers with `internal = false` or `scheme = "internet-facing"`
- Cloud Run / App Engine / Azure Container Apps ingress changing to unauthenticated

**Encryption changes:**
- `encrypted = false` on storage or databases
- KMS key being changed or deleted (`aws_kms_key`, `google_kms_crypto_key`, `azurerm_key_vault_key`)
- `storage_encrypted = false` on RDS; `disk_encryption_enabled = false` on Azure VMs

**Sensitive values:**
- `(sensitive value)` markers on attributes of new or modified resources — note their presence and resource context; flag if they appear in places that suggest credential injection

### 3. Blast radius

Quantify the scope:
- **Added**: count and list notable resource types
- **Changed in-place**: count and list notable resource types
- **Destroyed / replaced**: count and list by full resource address (most critical)
- **Foundational resources**: VPCs, subnets, shared security groups, DNS zones, IAM roles used by multiple services, KMS keys — any modification here has implicit downstream impact beyond what the plan lists

Assign a blast radius label:
- **Contained** — only new resources or isolated low-dependency existing resources
- **Moderate** — touching shared resources (security groups, IAM roles, subnets) used by multiple services
- **Wide** — foundational resources, cross-region/cross-account, or many replacements affecting live traffic

### 4. Operational risk

**Downtime:**
- Replace on resources serving live traffic: load balancers, instances, managed services without HA failover
- DNS record changes — propagation is TTL-dependent (often 5 min to 48 hr)
- TLS certificate changes on live endpoints
- Database parameter group changes requiring a reboot
- Auto Scaling Group replacement — brief capacity reduction during rollover

**Order sensitivity:**
- If changes have implicit ordering that Terraform may not enforce (missing `depends_on`), note the safe sequence
- General safe order: network / DNS → IAM → compute → application layer
- Flag any resource pair where a failure mid-plan leaves things in a broken intermediate state

**Rollback difficulty:**
- Stateful resources: Hard (data loss; must restore from backup)
- IAM / policy changes: Easy (re-run plan with previous state)
- DNS changes: Moderate (TTL-dependent)
- Certificate changes: Easy if prior cert not deleted
- Networking (SGs, routes): Moderate to Hard under live traffic

### 5. Drift indicators

Signs the plan contains unexpected changes worth confirming:
- Many `~ update` blocks that only touch `tags` — suggests manual tag changes accumulated outside Terraform
- Resources modified that aren't obviously related to the stated change intent
- `(known after apply)` on attributes that are normally stable — may indicate a provider version bump or attribute rename
- Accidental destroys — a resource being deleted that looks unintentional (typo in name, removed from wrong module)
- `-/+` replace where only a computed/provider-managed attribute changed — may be a provider behavior change, not a user change

Flag as "possibly unintended — confirm before applying."

### 6. Routine / expected changes

Explicitly identify what looks safe to reduce noise:
- New standalone resources with no dependencies on existing live infrastructure
- Tag-only updates on non-critical resources
- Scaling parameter updates (min/max capacity, timeout values)
- Adding new outputs, data sources, or locals
- Minor version bumps on resources that support in-place updates

## Output format (inline markdown — do not write to disk)

```markdown
# Terraform plan review

## Plan summary
- **Resources**: N to add · N to change · N to destroy · N to replace
- **Workspace / provider**: <if detectable from plan output>

---

## Risk verdict

> **SAFE TO APPLY** | **REVIEW CAREFULLY** | **HOLD — DESTRUCTIVE**

One sentence stating the primary reason for the verdict.

---

## Destructive changes

> _No destroys or replacements detected._ (use this line if truly empty — don't omit the section)

For each destroyed or replaced resource:
- **`resource_type.resource_name`** — `destroy` | `replace` | `force-replace`
  - **Reason for replacement**: <attribute that forces it, if shown in plan>
  - **Stateful?** Yes — <specific data loss risk> | No
  - **Rollback path**: Easy / Moderate / Hard — <one line>
  - **Safer alternative**: <create_before_destroy, snapshot first, ignore_changes — or "none apparent">

---

## Security findings

> _No security-relevant changes detected._ (use if empty)

For each finding:

**[CRITICAL | HIGH | MEDIUM | LOW]** `resource_type.resource_name` — <title>
- **What's changing**: <specific attribute, rule, or policy statement visible in plan>
- **Why it matters**: <risk>

---

## Blast radius

- **Scope**: Contained | Moderate | Wide
- **Added**: N (<notable types>)
- **Changed in-place**: N (<notable types>)
- **Destroyed / replaced**: N (<list full resource addresses>)
- **Implicit downstream risk**: <foundational resources whose change affects unlisted dependents, or "none">

---

## Operational risk

- **Downtime expected?** Yes / No / Possible — <which resources and estimated window if knowable>
- **Rollback difficulty**: Easy | Moderate | Hard — <one line>
- **Apply sequence note**: <only include if ordering matters; omit otherwise>

---

## Drift / unexpected changes

> _No unexpected changes detected._ (use if empty)

- `resource_type.resource_name` — <why this looks unexpected or unintended>

---

## What looks routine

- <resource or group> — <why it's low-risk>

---

## Bottom line

Two to four sentences. State the verdict plainly. Call out the single most important thing to verify or do before applying. State the rollback posture. No new findings here — synthesis only.
```

## Risk verdict rubric

**HOLD — DESTRUCTIVE** — any of:
- Stateful resource (database, storage, queue, cache, secrets store, volume) being destroyed or replaced
- Security group opening a sensitive port (22, 3389, or DB ports) to `0.0.0.0/0`
- IAM policy with `Action: "*"` and `Resource: "*"` being added
- Encryption disabled on a storage or database resource
- KMS key being deleted

**REVIEW CAREFULLY** — any of:
- Non-stateful replace (load balancer, compute instance, managed service) causing downtime
- IAM changes that aren't wildcard but are broad or unexpected
- New public-facing endpoint being added
- Foundational resource being modified (VPC, shared SG, DNS zone, shared IAM role)
- Wide blast radius
- Drift indicators present (changes not matching stated intent)

**SAFE TO APPLY** — all of:
- All changes are additions or in-place updates on non-shared resources
- No destroys or replacements
- No security posture changes
- Blast radius is contained

## Non-negotiables

- **Call out every `destroy` and every `replace` explicitly.** No grouping them away. Each gets its own bullet with full resource address and root cause.
- **State the verdict at the top**, large and visible. Don't bury it.
- **For security group / firewall findings, show the specific rule** — protocol, port range, CIDR source. Not just "security group changed."
- **For IAM findings, show the specific actions and resources** from the policy document as it appears in the plan.
- **If plan output is truncated or partial**, say so and state that the review is incomplete.
- **Quote resource addresses exactly** as they appear in the plan. Do not infer or fabricate names.
- **`(known after apply)` on security-relevant attributes** — flag as "cannot fully assess until applied" rather than assuming safe.
- **No org-specific standards** (naming conventions, mandatory tags, approved resource types) unless the user explicitly provides them.
- **Don't auto-apply.** This skill produces analysis only.
- **Honesty in the "routine" section.** If everything is risky, don't invent safe changes. If everything is routine, say so and keep the review short.
