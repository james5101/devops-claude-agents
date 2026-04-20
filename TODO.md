# TODO

Roadmap for the agent library. See [CLAUDE.md](CLAUDE.md) for authoring conventions.

## Shipped

- [x] `architecture-designer` front door (inline via `/design-architecture`)
- [x] `aws-architect`, `azure-architect`, `gcp-architect` cloud specialists (subagents)
- [x] `architecture-reviewer` (inline via `/review-architecture`), design-review + implementation-review modes
- [x] Mermaid diagrams, Well-Architected pillar mapping, T-shirt cost envelopes
- [x] CLAUDE.md with authoring conventions
- [x] Simulated smoke test of AWS single-cloud path (claims platform scenario)

## Architecture agents — follow-ups

- [ ] Real end-to-end smoke test of `/design-architecture` (post-restart, fresh session)
- [ ] Smoke test of **comparison mode** — user undecided on cloud, designer should fan out to all three specialists in parallel
- [ ] Smoke test of `/review-architecture` in both modes (design-review and implementation-review)
- [ ] Consider whether the specialist prompts should require returning risks verbatim so the front-door summary doesn't re-derive them
- [ ] Decide whether to keep the `architecture-designer.md` and `architecture-reviewer.md` subagent files (currently redundant with the inline slash commands; could be deleted or repurposed)

## Next agents to build (rough priority)

- [ ] **Troubleshooting agent(s)** — tabled during architecture work; open questions:
  - Runtime/production vs development-time issues?
  - Execute diagnostics (kubectl/aws/az/gcloud/terraform) or guide-only?
  - Common incident patterns to specialize on (ImagePullBackOff, Terraform state drift, GHA job hangs)?
- [ ] **Security-review agent** — likely scoped to IaC (Terraform/CDK/Helm) + CI/CD posture; separate from architecture-reviewer
- [ ] **IaC-authoring agent** — Terraform-first, module scaffolding, provider best practices; consider per-cloud specialists again
- [ ] **Code-review agent** — PR review against DevOps-specific criteria (infra changes, CI/CD changes, secrets handling)

## Nice-to-haves

- [ ] `.claude/settings.json` for the repo — sensible permission allowlist so the team doesn't get spammed with prompts (e.g. `Read`, `Glob`, `Grep`, `git status`, `git diff`)
- [ ] Example `docs/architecture/` design committed as a reference / template for the team
- [ ] CONTRIBUTING guide for team members adding new agents
- [ ] Linting / validation for agent frontmatter (catch typos in `model:` or missing `description:`)
