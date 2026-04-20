# CLAUDE.md

Instructions for Claude Code when working in this repository.

## What this repo is

A team-shared library of Claude Code subagents and slash commands for DevOps work. Currently scoped to **platform-level cloud architecture** (design + review); troubleshooting, security review, IaC authoring, and code review are on the roadmap. See [TODO.md](TODO.md).

## Conventions for adding agents and commands

### Rule 1 — Conversational workflows live in slash commands, not subagents

If a workflow asks the user questions and waits for answers, it MUST be implemented as an inline slash command in `.claude/commands/`. Do NOT put it in a subagent.

**Why:** When a slash command invokes a subagent, the subagent's output goes back to the parent agent, which summarizes rather than relaying verbatim. Clarifying questions get paraphrased into "please answer" and the user never sees them. This repo hit exactly that bug during initial authoring — the fix was to inline the front-door designer into `/design-architecture` rather than calling an `architecture-designer` subagent.

### Rule 2 — Subagents are for deep, non-conversational work

Subagents (`.claude/agents/`) should be reserved for:
- Producing long artifacts (e.g. writing a full design doc to disk)
- Deep analysis with its own context window
- Parallel fan-out (e.g. running AWS / Azure / GCP specialists concurrently)

A front door that asks questions and then delegates should be a **slash command that spawns subagents** — not a subagent itself.

### Rule 3 — Clarifying questions, in a batch, up front

Every agent that designs or reviews must ask clarifying questions as a single numbered batch before producing output. No best-guess first drafts. The command prompt should explicitly end with an instruction to stop after Step 1 and wait for answers.

### Rule 4 — No org-specific standards in prompts

Naming conventions, tagging rules, approved-service lists, and landing-zone deviations belong in policy-as-code (OPA, Checkov, tflint, Azure Policy, GCP Org Policies) — not hard-coded in agent prompts where they rot. If the user supplies org standards at invocation time, pass them through; otherwise do not fabricate them.

### Rule 5 — Framework-anchored

Cloud architecture agents evaluate against the canonical framework for that cloud:
- **AWS** → AWS Well-Architected Framework (6 pillars)
- **Azure** → Azure Well-Architected Framework (5 pillars) + ALZ / CAF alignment
- **GCP** → Google Cloud Architecture Framework (6 pillars) + Enterprise Foundations alignment

Be honest in pillar scoring. Do not default to green.

### Rule 6 — Reviewer identifies, does not propose

The reviewer agent outputs findings only. No "recommendation" sections, no code suggestions, no "you should…" paragraphs. Keeps critique sharp and separates problem-finding from solutioning.

### Rule 7 — IaC and tooling defaults

Unless the user says otherwise:
- IaC examples: **Terraform** (CDK acceptable when user indicates the project uses it)
- CI/CD: **GitHub Actions** with **OIDC** federation to cloud
- Diagrams: **Mermaid** (renders natively in GitHub/markdown)
- Kubernetes packaging: **Helm**

### Rule 8 — Model pinning

All architecture agents are pinned to **Opus** (`model: opus` in frontmatter). Architecture work is reasoning-heavy; Sonnet/Haiku cut corners. Revisit only for agents where speed clearly outweighs reasoning depth.

## File layout

```
.claude/
  agents/         # Subagents — deep, non-conversational work only
  commands/       # Slash commands — conversational workflows
docs/
  architecture/   # Generated design artifacts land here
CLAUDE.md         # This file — instructions for Claude
README.md         # Human-facing overview
TODO.md           # Roadmap
```

## Testing new agents

1. **Simulated smoke test** first — play both user and agent inline to sanity-check the prompt. Catches obvious issues without requiring a restart.
2. **Real smoke test** — restart Claude Code and invoke the slash command or subagent for real. Commands and subagents are discovered at session start.
3. **Comparison / fan-out modes** need their own smoke tests; don't assume a single-cloud test covers multi-cloud routing.

## Before committing

- Verify new commands ask clarifying questions up-front (Rule 3).
- Verify no org-specific standards have leaked into prompts (Rule 4).
- Update [TODO.md](TODO.md) if the roadmap changed.
- Update [README.md](README.md) if user-facing behavior changed.
