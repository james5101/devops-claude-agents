# TODO

Roadmap for the agent library. See [CLAUDE.md](CLAUDE.md) for authoring conventions.

## Shipped

- [x] `architecture-designer` front door (inline via `/design-architecture`)
- [x] `aws-architect`, `azure-architect`, `gcp-architect` cloud specialists (subagents)
- [x] `architecture-reviewer` (inline via `/review-architecture`), design-review + implementation-review modes
- [x] Mermaid diagrams, Well-Architected pillar mapping, T-shirt cost envelopes
- [x] CLAUDE.md with authoring conventions
- [x] Simulated smoke test of AWS single-cloud path (claims platform scenario)
- [x] Kubernetes read-only agent family, backed by `containers/kubernetes-mcp-server`:
  - `/k8s-troubleshoot` (inline, iterative)
  - `/k8s-diagnose-pod` (inline, narrow)
  - `/k8s-review` (inline Q&A → `kubernetes-reviewer` subagent → report in `docs/reviews/`)
  - Framework anchor: CIS K8s Benchmark + production-readiness + FinOps + operational excellence
- [x] `dockerfile-optimizer` skill — auto-triggers on Dockerfile review/optimize/audit requests; scans all Dockerfiles in repo, detects stack, produces inline diff-style optimization plan across six axes (size / cache / security / reproducibility / runtime / supply chain). Anchored on Docker best-practices + Hadolint rule IDs + CIS Docker Benchmark.
- [x] `github-actions-auditor` skill — auto-triggers on GHA workflow audit/review/optimize/harden requests; scans `.github/workflows/`, in-repo `action.yml` files, and `dependabot.yml`; detects stack; produces inline diff-style audit plan across six axes (security / reliability / efficiency / maintainability / correctness / supply chain). Anchored on GitHub security-hardening docs + actionlint + zizmor + OpenSSF Scorecard.
- [x] `terraform-plan-reviewer` skill — auto-triggers when `terraform plan` output is pasted or the user asks to review a plan; produces an inline risk-graded review across six axes (destructive changes / security / blast radius / operational risk / drift indicators / routine changes); emits a top-level verdict (SAFE TO APPLY / REVIEW CAREFULLY / HOLD — DESTRUCTIVE); stateful resources flagged at Critical on destroy/replace.
- [x] `/iac-author` slash command + `iac-author` subagent — clarifying-question front door delegates to a generation subagent that reads `.claude/iac-standards.md` (naming, tags, module sources, forbidden patterns, backend config), attempts MCP module lookup via `terraform-registry` server (`list_modules` / `get_module_schema` / `get_module_example`) with graceful fallback to approved public registry modules, then writes `.tf` files to disk. Security defaults baked in (encryption, no public access, no wildcard IAM, sensitive vars).

## Architecture agents — follow-ups

- [ ] Real end-to-end smoke test of `/design-architecture` (post-restart, fresh session)
- [ ] Smoke test of **comparison mode** — user undecided on cloud, designer should fan out to all three specialists in parallel
- [ ] Smoke test of `/review-architecture` in both modes (design-review and implementation-review)
- [ ] Consider whether the specialist prompts should require returning risks verbatim so the front-door summary doesn't re-derive them
- [ ] Decide whether to keep the `architecture-designer.md` and `architecture-reviewer.md` subagent files (currently redundant with the inline slash commands; could be deleted or repurposed)

## Kubernetes agents — follow-ups

- [ ] Real smoke test of `/k8s-troubleshoot`, `/k8s-diagnose-pod`, `/k8s-review` against a live cluster (post-restart, fresh session, MCP server installed)
- [ ] Simulated smoke test of `/k8s-review` subagent hand-off — verify severity-grouped report structure and top-3-findings return value
- [ ] Decide when to add a mutating `k8s-operator` agent; gate behind explicit human-in-the-loop before applying changes
- [ ] Consider a cloud-provider-flavored layer (EKS / AKS / GKE) — probably a thin tool-prefix extension rather than separate agents

## Dockerfile optimizer — follow-ups

- [ ] Real smoke test on a repo with multiple Dockerfiles (Node + Python + Go) to verify stack detection and per-file grouping
- [ ] Decide whether to add an opt-in companion that *applies* the proposed diffs (gate behind explicit confirmation, never auto-apply)
- [ ] Consider an optional CI integration recipe — Hadolint + Trivy + the skill's findings format

## GitHub Actions auditor — follow-ups

- [ ] Real smoke test against `examples/gha-audit-test/.github/workflows/` to verify all six axes fire and rule IDs are cited correctly
- [ ] Multi-stack fixture (Node + Python + Go workflows in one repo) to verify per-file stack detection
- [ ] Decide whether to add an opt-in companion that *applies* the proposed diffs (gate behind explicit confirmation, never auto-apply)
- [ ] Consider integration recipe — actionlint + zizmor + the skill's output format as a CI gate

## IaC author — follow-ups

- [x] Smoke test `/iac-author` against a real request ("private EKS cluster with 3 nodes") — subagent wrote valid `.tf` files to `generated/iac/eks-private/`; note: new subagents require a session restart to be discoverable, so the generation ran via `general-purpose` with the full iac-author prompt embedded
- [ ] Build the `terraform-registry` MCP server — implement `list_modules`, `get_module_schema`, `get_module_example` backed by your internal registry API (Terraform Cloud, Artifactory, or custom)
- [ ] Add a `tflint` / `checkov` validation pass as an optional post-generation step — agent runs the tool against its own output and surfaces violations before returning
- [ ] Decide whether to support CDK (TypeScript) as an alternate output shape — likely a separate `cdk-author` subagent rather than complicating this one
- [ ] Consider a `--dry-run` mode that returns the generated code inline without writing to disk (useful for quick review before committing)

## Terraform plan reviewer — follow-ups

- [ ] Smoke test against a real plan with stateful resource replacements to verify Critical verdict fires correctly
- [ ] Smoke test against a plan with IAM wildcard additions to verify security axis catches it
- [x] JSON plan format (`terraform show -json tfplan`) confirmed working — skill accepted pasted JSON output and produced full 6-axis review; no code changes needed, the skill handles both formats
- [ ] Consider a companion that reads plan from a file path directly (user provides `plan.out` path, skill reads it)
- [ ] Consider integration recipe — run as a CI step and post the verdict as a PR comment (would require a companion script, not the skill itself)

## Next agents to build (rough priority)

- [ ] Non-k8s troubleshooting — Terraform state drift, GHA job hangs, generic cloud-resource debugging (separate from the k8s family)
- [ ] **Security-review agent** — likely scoped to IaC (Terraform/CDK/Helm) + CI/CD posture; separate from architecture-reviewer
- [ ] **IaC-authoring agent** — Terraform-first, module scaffolding, provider best practices; consider per-cloud specialists again
- [ ] **Code-review agent** — PR review against DevOps-specific criteria (infra changes, CI/CD changes, secrets handling)

## Nice-to-haves

- [ ] `.claude/settings.json` for the repo — sensible permission allowlist so the team doesn't get spammed with prompts (e.g. `Read`, `Glob`, `Grep`, `git status`, `git diff`)
- [ ] Example `docs/architecture/` design committed as a reference / template for the team
- [ ] CONTRIBUTING guide for team members adding new agents
- [ ] Linting / validation for agent frontmatter (catch typos in `model:` or missing `description:`)
