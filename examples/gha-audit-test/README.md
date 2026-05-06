# gha-audit-test

Deliberately unoptimized GitHub Actions workflows, used to smoke-test the
[`github-actions-auditor`](../../.claude/skills/github-actions-auditor/SKILL.md) skill.

The workflows in `.github/workflows/` are **intentionally bad**. They hit as
many of the six axes as possible (security, reliability, efficiency,
maintainability, correctness, supply chain) so the skill has plenty to find.
Do not use them as templates — that is the opposite of their purpose.

To exercise the skill, ask Claude something like:

> Audit the GitHub Actions workflows in examples/gha-audit-test and produce an optimization plan.

The skill should auto-trigger on that request and produce a severity-grouped
plan with actionlint / zizmor / Scorecard rule IDs cited.

> **Note:** the `.github/workflows/` directory is nested under this example
> dir specifically so it does not run on this repo. Real workflows live at
> the repo root `.github/workflows/`, not here.
