# devops-claude-agents

A team-shared library of [Claude Code](https://docs.claude.com/en/docs/claude-code) subagents, slash commands, and skills for DevOps work — starting with cloud architecture, Kubernetes, and container build hygiene.

## What's here

```
.claude/
  agents/
    architecture-designer.md     # Front door for greenfield platform design
    architecture-reviewer.md     # Critiques designs or IaC against cloud WAFs
    aws-architect.md             # AWS specialist (invoked by the designer)
    azure-architect.md           # Azure specialist
    gcp-architect.md             # GCP specialist
    kubernetes-reviewer.md       # Posture-review specialist (invoked by /k8s-review)
  commands/
    design-architecture.md       # /design-architecture slash command
    review-architecture.md       # /review-architecture slash command
    k8s-troubleshoot.md          # /k8s-troubleshoot — iterative symptom investigation
    k8s-diagnose-pod.md          # /k8s-diagnose-pod — focused pod diagnosis
    k8s-review.md                # /k8s-review — cluster/namespace/manifest posture review
  skills/
    dockerfile-optimizer/        # Auto-triggers on Dockerfile review/optimize requests
    github-actions-auditor/      # Auto-triggers on GHA workflow audit/review/optimize requests
    terraform-plan-reviewer/     # Auto-triggers when terraform plan output is pasted or reviewed
docs/
  architecture/                  # Generated design artifacts land here
  reviews/                       # Generated review reports (e.g. k8s posture) land here
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

### Kubernetes troubleshooting and review

Three commands, all read-only, all backed by the [`containers/kubernetes-mcp-server`](https://github.com/containers/kubernetes-mcp-server) MCP server:

```
/k8s-troubleshoot            # iterative, hypothesis-driven — "pods in checkout are OOMKilling"
/k8s-diagnose-pod            # focused — "tell me what's wrong with checkout/api-7b8f-abcde"
/k8s-review                  # posture review, writes a findings report to docs/reviews/
```

Troubleshoot and diagnose-pod run inline (iterative flows need to ask mid-flow questions). `/k8s-review` runs the Q&A inline and then delegates to the `kubernetes-reviewer` subagent, which writes a severity-grouped report against a composite anchor (CIS Kubernetes Benchmark + production-readiness patterns + FinOps heuristics + operational excellence).

#### Installing the Kubernetes MCP server

The MCP server is not bundled — install it once per machine. Easiest path for Claude Code:

```bash
claude mcp add kubernetes -- npx -y kubernetes-mcp-server@latest --read-only
```

Or pin via a checked-in `.mcp.json` at the root of any project that uses these commands:

```json
{
  "mcpServers": {
    "kubernetes": {
      "command": "npx",
      "args": ["-y", "kubernetes-mcp-server@latest", "--read-only"]
    }
  }
}
```

Alternatives: native binary, Python package, or container image — see the [upstream repo](https://github.com/containers/kubernetes-mcp-server).

Notes:
- `--read-only` disables mutating tools at the server. The commands assume this flag is set; don't remove it unless you explicitly want mutation.
- The server reads your kubeconfig and supports all contexts by default (multi-cluster on). Add `--disable-multi-cluster` if you want to scope to `current-context` only.
- For OIDC / OAuth / in-cluster deployment, see the upstream docs.

### Dockerfile review and optimization

`dockerfile-optimizer` is a **skill**, not a slash command — it auto-triggers when you ask Claude to review, optimize, audit, lint, harden, or shrink a Dockerfile. No invocation needed.

It scans every Dockerfile / Containerfile in the repo, detects the language stack per file (Node / Python / Go / Java / Rust / Ruby), and produces an inline diff-style optimization plan grouped by severity. Anchored on three layered references:

- [Docker official build best-practices](https://docs.docker.com/build/building/best-practices/)
- [Hadolint rule IDs](https://github.com/hadolint/hadolint) (DL3008, DL3015, DL3025, DL4006, etc.)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) for security findings

Coverage axes (all six, every invocation): image size, build-cache hit rate, security, reproducibility, runtime hygiene (signal handling, HEALTHCHECK, CMD form), supply chain (provenance, SBOM, base trust). Proposes concrete fixes as diffs; does not auto-apply.

### Terraform plan review

`terraform-plan-reviewer` is a **skill** — it auto-triggers when you paste `terraform plan` output into the chat or ask to review/analyze a plan.

Run `terraform plan` in your terminal, paste the output, and the skill immediately produces a risk-graded review:

- **Risk verdict** — SAFE TO APPLY / REVIEW CAREFULLY / HOLD — DESTRUCTIVE
- **Destructive changes** — every `destroy` and `replace` called out by resource address, with root cause and rollback difficulty
- **Security findings** — IAM wildcard policies, firewall rules opening ports to 0.0.0.0/0, encryption changes, public access changes
- **Blast radius** — scope label (Contained / Moderate / Wide) plus downstream risk for foundational resources
- **Operational risk** — expected downtime, rollback difficulty, apply-order sensitivity
- **Drift indicators** — unexpected changes that don't match stated intent
- **What's routine** — safe changes called out explicitly to reduce noise

Stateful resources (databases, storage, queues, caches, secrets stores) are flagged at Critical severity when destroyed or replaced, since data loss may be permanent.

### GitHub Actions audit and optimization

`github-actions-auditor` is a **skill** — it auto-triggers when you ask Claude to review, audit, optimize, lint, or harden GitHub Actions workflows, reusable workflows, or composite actions.

It scans every file under `.github/workflows/`, every in-repo `action.yml`, and `dependabot.yml`, detects the language stack per workflow, and produces an inline diff-style audit plan grouped by severity. Anchored on:

- [GitHub: Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [actionlint](https://github.com/rhysd/actionlint) rule names
- [zizmor](https://github.com/woodruffw/zizmor) finding IDs (`template-injection`, `artipacked`, `dangerous-triggers`, `unpinned-uses`, `excessive-permissions`, …)
- [OpenSSF Scorecard](https://github.com/ossf/scorecard) checks (`Pinned-Dependencies`, `Token-Permissions`, `Dangerous-Workflow`)

Coverage axes (all six, every invocation): security, reliability, efficiency/cost, maintainability, correctness, supply chain. Proposes concrete fixes as diffs; does not auto-apply.

## Design principles baked into these agents

- **Platform-level only.** App-level topology is out of scope.
- **Clarifying questions up-front, in a batch.** No best-guess first drafts.
- **Framework-anchored.** AWS Well-Architected, Azure WAF, or Google Cloud Architecture Framework depending on cloud.
- **No org-specific standards hard-coded.** Naming, tagging, approved-service lists belong in policy-as-code (OPA, Checkov, Azure Policy, Org Policies) — not in prompt text where they drift.
- **Reviewer identifies, does not propose** — for *architecture* (high-stakes, cross-cutting). For local artifacts like Dockerfiles, the optimizer *does* propose concrete diffs because the blast radius is small and the user wants actionable output.
- **Terraform-first** in code examples; CDK supported where the user indicates it.
- **Opus** is pinned as the model for all agents — architecture work is reasoning-heavy.

## Roadmap

Planned but not yet built:
- Security-review agent
- IaC-authoring agent
- Code-review agent
- Mutating Kubernetes operator agent (currently scoped read-only)
- Incident / alert triage assistant (non-k8s cloud resource diagnosis)
- PR description generator for infra changes
- On-call handoff generator
