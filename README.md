# devops-claude-agents

A team-shared library of [Claude Code](https://docs.claude.com/en/docs/claude-code) subagents and slash commands for DevOps work — starting with cloud architecture.

## What's here

```
.claude/
  agents/
    architecture-designer.md     # Front door for greenfield platform design
    architecture-reviewer.md     # Critiques designs or IaC against cloud WAFs
    aws-architect.md             # AWS specialist (invoked by the designer)
    azure-architect.md           # Azure specialist
    gcp-architect.md             # GCP specialist
  commands/
    design-architecture.md       # /design-architecture slash command
    review-architecture.md       # /review-architecture slash command
docs/
  architecture/                  # Generated design artifacts land here
```

## How to use

Clone this repo and open it in Claude Code, or copy `.claude/` into your own project.

### Design a new platform

```
/design-architecture
```

or with a hint:

```
/design-architecture ingestion platform for ~50k msg/sec, GDPR-sensitive
```

The `architecture-designer` agent will:
1. Ask a batch of clarifying questions (business context, cloud, regions, compliance, NFRs, etc.).
2. Delegate to `aws-architect`, `azure-architect`, or `gcp-architect` — or fan out to all three in parallel if you're cloud-undecided.
3. Write the design (Mermaid diagrams, Well-Architected mapping, cost envelope) to `docs/architecture/<slug>.md`.
4. Return a summary with file paths and key decisions.

### Review an existing design or implementation

```
/review-architecture
```

or:

```
/review-architecture docs/architecture/my-platform.md
```

The `architecture-reviewer` runs in two modes:
- **design-review** — input is a design doc.
- **implementation-review** — input is a design doc + the IaC that implements it. Checks faithfulness and latent issues (over-broad IAM, public exposure, missing encryption, etc.).

It produces findings only — no proposed fixes. Severity-grouped + pillar-grouped + a pillar scorecard + explicit strengths.

## Design principles baked into these agents

- **Platform-level only.** App-level topology is out of scope.
- **Clarifying questions up-front, in a batch.** No best-guess first drafts.
- **Framework-anchored.** AWS Well-Architected, Azure WAF, or Google Cloud Architecture Framework depending on cloud.
- **No org-specific standards hard-coded.** Naming, tagging, approved-service lists belong in policy-as-code (OPA, Checkov, Azure Policy, Org Policies) — not in prompt text where they drift.
- **Reviewer identifies, does not propose.** Keeps critique sharp and separates problem-finding from solutioning.
- **Terraform-first** in code examples; CDK supported where the user indicates it.
- **Opus** is pinned as the model for all agents — architecture work is reasoning-heavy.

## Roadmap

Planned but not yet built:
- Troubleshooting agent(s)
- Security-review agent
- IaC-authoring agent
- Code-review agent
