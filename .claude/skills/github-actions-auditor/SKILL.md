---
name: github-actions-auditor
description: Audit GitHub Actions workflows in the current repo and produce a prioritized, diff-style optimization plan covering security, reliability, efficiency/cost, maintainability, correctness, and supply chain. Use when the user asks to review, audit, optimize, lint, or harden GitHub Actions workflows, reusable workflows, or composite actions, when a file under `.github/workflows/` or an `action.yml` is the focus of the request, or when the user wants to know what's wrong with their CI/CD pipeline on GitHub. Anchored on GitHub's official "Security hardening for GitHub Actions" and workflow-optimization docs, actionlint rule names, zizmor finding IDs (template-injection, artipacked, dangerous-triggers, etc.), and OpenSSF Scorecard checks (Pinned-Dependencies, Token-Permissions, Dangerous-Workflow).
---

# GitHub Actions auditor

Reviews every GitHub Actions workflow, reusable workflow, and in-repo composite/custom action in the working repo and produces a single inline markdown audit plan. Proposes concrete fixes (diff-style); does not auto-apply them.

## When this skill triggers

The user asks for review, audit, optimization, lint, hardening, or reliability/efficiency analysis of GitHub Actions workflows, a CI/CD pipeline on GitHub, or a specific workflow file. Also when the user opens a workflow under `.github/workflows/` and asks "what's wrong with this" or "make this better."

If the user wants a generic CI/CD strategy discussion (not tied to existing workflow files), this skill is the wrong shape — answer conversationally instead.

## Scope per invocation

- **Discover** all workflow files under `.github/workflows/*.{yml,yaml}` (use Glob). Also discover in-repo composite/custom actions (`**/action.yml`, `**/action.yaml`) and any reusable workflows called via `uses: ./.github/workflows/...` or `uses: <owner>/<repo>/.github/workflows/...@<ref>`.
- **Read** each one fully. Read `dependabot.yml` too if it exists — its absence (or missing `package-ecosystem: github-actions`) is itself a finding.
- **Detect language/stack** from `setup-*` actions, build steps, and nearby manifests (`package.json`, `pyproject.toml`, `go.mod`, `pom.xml`, `Cargo.toml`, `Gemfile`). Tailor cache and matrix advice to the stack.
- Produce **one combined plan** covering all workflows found. Group findings per-file; share cross-cutting findings (e.g. no `permissions:` default, no Dependabot for `github-actions`) once.

## What to evaluate (six axes — all of them, every time)

### 1. Security
- **Token permissions** — top-level `permissions:` set to least-privilege (ideally `contents: read`); job-level escalation only where needed. Missing top-level `permissions:` is a finding (zizmor `excessive-permissions`, Scorecard `Token-Permissions`).
- **Action pinning** — third-party actions pinned by full commit SHA, not by tag or branch (zizmor `unpinned-uses`, Scorecard `Pinned-Dependencies`). First-party `actions/*` and `github/*` MAY use major-version tags; call out the trade-off.
- **`pull_request_target` misuse** — never combined with `actions/checkout` of the PR head ref without an explicit safety gate (zizmor `dangerous-triggers`, Scorecard `Dangerous-Workflow`). This is the single highest-severity finding when present.
- **Script injection** — `${{ github.event.*.title }}`, `${{ github.head_ref }}`, `${{ github.event.issue.body }}`, etc. interpolated directly into `run:` shell blocks (zizmor `template-injection`). Fix is to pass via `env:` and reference `"$VAR"`.
- **Secrets discipline** — no secrets echoed in `run:` lines, no `printenv`/`env` dumps, no `secrets.*` in `if:` conditions on untrusted-trigger workflows. Prefer OIDC federation (`permissions: id-token: write` + `aws-actions/configure-aws-credentials` etc.) over long-lived cloud credentials stored in `secrets`.
- **Artifact poisoning** — uploading the entire workspace via `actions/upload-artifact` with no `path:` filter (zizmor `artipacked`) leaks `.git/config` containing a token.
- **`GITHUB_TOKEN` reuse across jobs** — explicit `secrets: inherit` in reusable-workflow calls when not needed.
- **Self-hosted runners on public repos** — flag immediately; ephemeral runners only.

### 2. Reliability
- **`timeout-minutes`** — set per job (and per long step). Default is 360 minutes — runaway jobs burn minutes and block queues. (actionlint does not enforce this; cite GitHub docs.)
- **`concurrency`** — workflow- or job-level `concurrency:` group with `cancel-in-progress: true` for PR/push triggers; deployment workflows use a serializing group with `cancel-in-progress: false`.
- **Matrix `fail-fast`** — explicit `strategy.fail-fast: false` for test matrices where you want full signal; default `true` is right for build matrices.
- **Retry discipline** — `continue-on-error: true` only where genuinely advisory; otherwise it silently masks failures. Recommend `nick-fields/retry` (pinned by SHA) for known-flaky network steps rather than blanket `continue-on-error`.
- **Required-status-check alignment** — when a workflow defines jobs that branch protection depends on, matrix-generated job names must be stable. Call out matrix configs whose job names will change if the matrix changes.
- **Deprecated runner images / action versions** — `ubuntu-18.04`, `ubuntu-20.04` (deprecated), `actions/checkout@v2`, `actions/upload-artifact@v3` (deprecated April 2024), `actions/cache@v2`, `set-output`/`save-state` workflow commands (deprecated; use `$GITHUB_OUTPUT`/`$GITHUB_STATE`).

### 3. Efficiency / cost
- **Runner sizing** — `ubuntu-latest` is the right default; flag `macos-latest` and `windows-latest` usage (≈10× and ≈2× the cost) for steps that could run on Linux. Flag `runs-on: [self-hosted, large]` without a comment justifying it.
- **Caching** — `setup-node`, `setup-python`, `setup-java`, `setup-go` all have built-in `cache:` inputs; prefer those over hand-rolled `actions/cache` for the standard dep dirs. For non-standard caches (build outputs, Docker layers), use `actions/cache` with a precise `key` and `restore-keys` fallback.
- **Redundant installs** — same `npm ci` / `pip install` repeated across jobs without sharing via cache or artifact.
- **Matrix explosion** — N×M×K matrices that produce 30+ jobs for marginal coverage. Recommend `include:`/`exclude:` to prune.
- **Path filters** — `on.push.paths` / `on.pull_request.paths` to skip workflows when irrelevant files change. Especially valuable for monorepos.
- **Job parallelism vs serialization** — `needs:` chains that serialize independent work; flag jobs that don't actually depend on each other.
- **Artifact retention** — `actions/upload-artifact` with default 90-day retention for ephemeral debug artifacts. Set `retention-days:` explicitly.
- **Workflow triggers on `**`** — `on: push` with no branch filter fires on every branch push, doubling spend on PR branches that already trigger via `pull_request`.

### 4. Maintainability
- **Reusable workflows** — repeated job blocks across workflows belong in `.github/workflows/_reusable-*.yml` called via `workflow_call`.
- **Composite actions** — repeated step sequences (≥3 steps used in ≥2 places) belong in `.github/actions/<name>/action.yml`.
- **DRY** — duplicated `env:`, duplicated `setup-*` blocks, duplicated build commands.
- **`env:` scoping** — workflow-level env for true globals; job/step-level for narrow values. Avoid mixing.
- **Naming** — `name:` on workflows, jobs, and significant steps so the Checks UI is readable.
- **Workflow file count** — one workflow doing 10 unrelated things vs ten focused workflows; lean toward focused with `workflow_call` for shared logic.

### 5. Correctness
- **`if:` conditions** — common footguns: `if: github.event_name == 'push'` as a string vs expression, `${{ }}` wrapping inside `if:` (allowed but not required and often misused), `always()` vs `success()` vs `failure()` semantics in cleanup steps.
- **`needs:` graph** — every job referenced in `needs:` must exist; missing dependencies silently skip.
- **`outputs:` wiring** — job/step outputs declared but never consumed, or consumed but never declared. Verify the chain.
- **Expression syntax** — `${{ secrets.FOO }}` inside single-quoted strings (won't expand), `toJSON()` vs `toJson()` (latter is wrong), missing `fromJSON()` when consuming a stringified matrix.
- **Trigger correctness** — `on: pull_request` without `types:` defaults to `[opened, synchronize, reopened]` which is usually correct; flag explicit `types: [labeled]`-only triggers as a correctness/security smell.
- **Default shell** — Windows runners default to PowerShell; cross-platform matrices should set `defaults.run.shell: bash` or per-step `shell: bash`.
- **Set `pipefail`** — `defaults.run.shell: bash` already runs with `-eo pipefail` on Linux/macOS by default in Actions; call out custom `shell: sh` usage that loses this.

### 6. Supply chain
- **Dependabot for Actions** — `.github/dependabot.yml` includes `package-ecosystem: "github-actions"` so SHA-pinned actions get automated update PRs. Without this, SHA pinning rots.
- **Action source trust** — flag actions from unverified publishers. Prefer official (`actions/*`, `github/*`), verified-creator marketplace actions, or vendored copies. Call out unofficial sources by name.
- **Provenance / attestations** — for workflows that build release artifacts, recommend `actions/attest-build-provenance` to produce SLSA provenance.
- **OIDC over secrets** — for cloud deploys (AWS/Azure/GCP), use OIDC federation (`permissions: id-token: write`) rather than long-lived `AWS_ACCESS_KEY_ID` / `AZURE_CREDENTIALS` / `GCP_SA_KEY` in secrets.
- **Allow-listing** — note when the org/repo would benefit from `Settings → Actions → Allow specified actions and reusable workflows` policy (recommendation, not a per-workflow finding).

## Output format (inline markdown — do not write to disk)

```markdown
# GitHub Actions audit plan

## Inventory
- `.github/workflows/<file>.yml` — trigger: `<events>`, jobs: <n>, runners: `<labels>`, detected stack: <node|python|go|…>
- `.github/workflows/<file>.yml` — …
- `.github/actions/<name>/action.yml` — composite/JS/Docker action
- `.github/dependabot.yml` — present (covers github-actions: yes/no) | MISSING

## Findings — severity-grouped

### Critical
For each finding:
- **Title** — one line
- **File**: `path:line`
- **Rule**: actionlint `<rule>` / zizmor `<finding-id>` / Scorecard `<check>` / GitHub docs: `<section>`
- **Why it matters**: risk or cost
- **Fix** (diff):
  ```diff
  - <old line(s)>
  + <new line(s)>
  ```

### High
…

### Medium
…

### Low
…

## Findings — by axis

Brief recap, grouped by the six axes (security / reliability / efficiency / maintainability / correctness / supply chain). Just titles + file refs.

## Quick wins (prioritized order to apply)
1. <highest-leverage change first>
2. …
3. …

## What these workflows already do well
Explicitly list strengths. A plan with no strengths is not credible.

## Bottom line
One short paragraph (3–5 lines max). State what must be fixed before these workflows run on any branch protected by required checks (or before the next release tag), and what the highest-leverage non-blocking fixes are. No new findings here — pure synthesis.
```

## Severity rubric
- **Critical** — `pull_request_target` + checkout of PR head without gate; secrets echoed in `run:`; long-lived cloud creds where OIDC is viable; self-hosted runners on a public repo; `permissions: write-all` on a workflow that runs untrusted PR code.
- **High** — no top-level `permissions:`; third-party actions pinned by tag/branch; template-injection via `github.event.*` in `run:`; deprecated `actions/upload-artifact@v3` or older `checkout`; no `timeout-minutes` on long-running jobs; no `concurrency` on PR-triggered workflows.
- **Medium** — missing built-in cache on `setup-*`; matrix explosion; macOS/Windows runners where Linux works; missing Dependabot for `github-actions`; redundant installs across jobs; default 90-day artifact retention for debug artifacts.
- **Low** — naming, `env:` scoping, missing `name:` on jobs/steps, trigger filters that could be tighter, style nits.

## Non-negotiables
- **One finding per rule.** Don't bundle multiple distinct actionlint, zizmor, or Scorecard rules into a single finding even if they appear on adjacent lines. Each rule gets its own title, severity, and diff. Cross-reference related findings in the "Why it matters" line if useful.
- **Cite rule IDs** for every finding where one applies — actionlint rule name, zizmor finding ID, Scorecard check name, or "GitHub docs: <section>". No hand-waved findings.
- **Always provide a concrete diff** for proposed fixes. No "you should consider…" without showing the change. For SHA-pinning fixes, use a placeholder SHA (`<commit-sha>`) and note "resolve current SHA at apply time" — don't fabricate hashes.
- **Don't auto-apply.** This skill produces a plan only — the user (or a separate edit pass) applies the diffs.
- **No org-specific standards** (mandatory reviewers, required workflows from an org `.github` repo, internal action allow-lists) unless the user supplies them in the request.
- **Tailor to detected stack.** Generic advice when you can't tell; specific advice (e.g. `setup-node` `cache: 'npm'`) when the stack is obvious.
- **Honesty in strengths.** If the workflows are already good, say so plainly and keep the plan short.
