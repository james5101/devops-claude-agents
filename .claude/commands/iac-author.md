---
description: Scaffold production-ready Terraform IaC for a described resource or platform component. Reads org standards from .claude/iac-standards.md if present. Consults internal module registry via MCP if configured. Writes output to generated/iac/<slug>/.
argument-hint: [optional: brief description, e.g. "private EKS cluster with IRSA" or "networking stack for prod VPC"]
---

You are the front door for the IaC authoring workflow. Your job is to gather requirements inline and hand off to the `iac-author` subagent which produces the Terraform files.

User-provided hint (may be empty): $ARGUMENTS

## Preconditions

**Standards file:** Check for `.claude/iac-standards.md` using the Read tool. If it exists, read it now and hold its contents — you will pass it to the subagent verbatim. If it does not exist, note that no org standards are loaded and proceed without fabricating any.

**MCP module registry:** The `iac-author` subagent will attempt to query a `terraform-registry` MCP server if configured. No action needed from you — the subagent handles this and falls back gracefully.

## Step 1 — Clarify (mandatory, batch, in-thread)

Send the user a single numbered batch of clarifying questions and STOP. Do not spawn the subagent until answers arrive. Pre-fill any question you can answer confidently from the user's hint — but still list it so the user can correct it.

1. **What do you need built?** Describe the resource(s) or component — be as specific as you can (e.g. "private EKS 1.30 cluster with IRSA and Karpenter", "S3 bucket with versioning and server-side encryption", "VPC with 3 AZs, public + private subnets, NAT gateway").
2. **Cloud provider** — AWS / Azure / GCP?
3. **Environment** — dev / staging / prod? (Affects sizing, HA, backup policies, and variable defaults.)
4. **Output shape** — standalone root module (ready to `terraform apply`) or a reusable module (with `variables.tf` / `outputs.tf` designed for composition)?
5. **Output path** — where should the files land? Default: `generated/iac/<slug>/`. Override if you have a preferred location in the repo.
6. **Constraints or context** — anything else that should shape the output: existing VPC / subnet IDs to deploy into, instance types, required features, things to avoid, links to related design docs.

## Step 2 — Delegate (only after answers arrive)

Spawn the `iac-author` subagent via the Agent tool. The prompt MUST include:

- The full requirements brief (resource description, cloud, environment, output shape, output path, constraints).
- The full contents of `.claude/iac-standards.md` if it was present — paste verbatim under a `## Org standards` heading. If the file was absent, say "No org standards file found — apply sensible defaults and public registry modules."
- An explicit instruction: **"Write all generated files to `<output-path>` using the Write tool. Returning code inline only is a failure mode — the user expects files on disk."**
- A reminder to attempt MCP module lookups via the `terraform-registry` server before falling back to public registry modules, and to document which path was taken.
- A reminder to return to the caller: the list of files written, a summary of modules used (internal vs public), and any assumptions made.

Do not pre-filter, paraphrase, or interpret the user's constraints. Pass them through.

## Step 3 — Hand back

After the subagent returns, present to the user:
- The files written (paths).
- Which modules were sourced (internal via MCP, or public registry — and from where).
- Key assumptions the subagent made.
- A one-line next-step nudge (e.g. "Run `terraform init && terraform plan` to validate, then `/review-architecture` if you want a WAF-lens review of the design.").

## Non-negotiables

- Clarifying questions first, in one batch. No best-guess code generation.
- Pass org standards through verbatim — do not interpret or summarize them before handing to the subagent.
- No org-specific standards fabrication (Rule 4). If no standards file exists, say so.
- The subagent MUST write files to disk. If it returns inline only, that is a failure.

**Now: read `.claude/iac-standards.md` if it exists, then produce Step 1's clarifying-question batch and stop.**
