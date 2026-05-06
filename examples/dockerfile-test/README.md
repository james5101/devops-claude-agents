# dockerfile-test

Deliberately unoptimized Dockerfile + tiny Flask app, used to smoke-test the
[`dockerfile-optimizer`](../../.claude/skills/dockerfile-optimizer/SKILL.md) skill.

The Dockerfile in this directory is **intentionally bad**. It hits as many of
the six axes as possible (size, cache, security, reproducibility, runtime,
supply chain) so the skill has plenty to find. Do not use it as a template —
that is the opposite of its purpose.

To exercise the skill, ask Claude something like:

> Review the Dockerfile in examples/dockerfile-test and produce an optimization plan.

The skill should auto-trigger on that request and produce a severity-grouped
plan with Hadolint / CIS rule IDs cited.
