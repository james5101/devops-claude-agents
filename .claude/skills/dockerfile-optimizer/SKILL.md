---
name: dockerfile-optimizer
description: Review Dockerfiles in the current repo and produce a prioritized, diff-style optimization plan covering image size, build-cache hit rate, security, reproducibility, runtime hygiene, and supply chain. Use when the user asks to review, optimize, audit, lint, shrink, or harden a Dockerfile or container image build, when a Dockerfile is the focus of the request, or when the user wants to know what's wrong with their `Dockerfile` / `Containerfile` / multi-stage build. Anchored on Docker's official build best-practices, Hadolint rules (cited by ID — DL3008, DL3015, DL3018, DL3020, DL3025, DL3027, DL4006, etc.), and the CIS Docker Benchmark for security findings.
---

# Dockerfile optimizer

Reviews every Dockerfile in the working repo and produces a single inline markdown optimization plan. Proposes concrete fixes (diff-style); does not auto-apply them.

## When this skill triggers

The user asks for review, optimization, audit, lint, hardening, or size/speed analysis of a Dockerfile, container build, or image. Also when the user opens a Dockerfile and asks "what's wrong with this" or "make this better."

If the user only wants a runtime/k8s issue diagnosed, hand off to the k8s troubleshooting commands instead.

## Scope per invocation

- **Discover** all `Dockerfile`, `Dockerfile.*`, `*.Dockerfile`, and `Containerfile` files in the repo (use Glob). Also check `docker-bake.hcl` and `compose.y*ml` for build contexts that pin to specific Dockerfiles.
- **Read** each one fully. Read `.dockerignore` too — its absence is itself a finding.
- **Detect language/framework** per Dockerfile from base image + `COPY` patterns + nearby manifests (`package.json`, `pyproject.toml` / `requirements.txt`, `go.mod`, `pom.xml`, `Cargo.toml`, `Gemfile`). Tailor advice to the stack.
- Produce **one combined plan** covering all Dockerfiles found. Group findings per-file; share cross-cutting findings (e.g. missing `.dockerignore`) once.

## What to evaluate (six axes — all of them, every time)

### 1. Image size
- Base image choice: `-slim`, `-alpine`, distroless, `scratch` where viable. Call out `:latest` (DL3007) and unpinned bases.
- Multi-stage hygiene: build deps not leaking into final stage; final stage starts from minimal base.
- Package manager hygiene: `apt-get update && apt-get install -y --no-install-recommends … && rm -rf /var/lib/apt/lists/*` in one layer (DL3009, DL3015). `apk add --no-cache` (DL3018). `pip install --no-cache-dir`. `npm ci --omit=dev` (or production install) and clear cache (DL3016 for npm pinning).
- `.dockerignore` present and excludes `.git`, `node_modules`, build artifacts, `.env*`, `**/*.md` for non-doc images.
- Avoid `ADD` for local files (DL3020) — `COPY` is smaller and clearer; `ADD` only for tarball auto-extract or remote URL with checksum.
- Detect large data committed into image (model weights, fixtures) that belong in a volume or object store.

### 2. Build speed / layer cache
- Instruction ordering: stable layers (deps install) before volatile layers (`COPY . .`). Manifest-only copy, install, then source copy is the canonical pattern for Node/Python/Go.
- COPY granularity: don't `COPY . .` before installing deps.
- Avoid invalidating cache with `ARG` placement that touches every layer.
- Recommend BuildKit cache mounts (`RUN --mount=type=cache,target=/root/.cache/pip`) for package managers, and `--mount=type=bind` for dep manifests when appropriate.
- Multi-stage parallelism: independent stages should not serialize unnecessarily.

### 3. Security
- **Non-root user** — `USER` directive present, UID set, filesystem ownership correct (DL3002). CIS 4.1.
- **Pinned base** — prefer digest pin (`@sha256:…`) for production; minimum is a specific tag, never `:latest` (DL3007). CIS 4.2.
- **No secrets in layers** — scan for `ENV`/`ARG` named like `*TOKEN*`, `*KEY*`, `*PASSWORD*`, `*SECRET*`. Recommend BuildKit `--mount=type=secret`. CIS 4.10.
- **No `curl | sh`** patterns; verify checksums for downloaded binaries.
- **APT/APK pinning** — package version pinning (DL3008 for apt, DL3018 for apk) for reproducible security patches. Trade-off: pinning vs unattended security updates — call out the trade-off, don't blanket-mandate.
- **Drop setuid/setgid binaries** if unused; consider `RUN find / -perm /6000 -type f -exec chmod a-s {} \\;` only when justified.
- **HEALTHCHECK** present where appropriate (DL3057). CIS 4.6.
- **No `sudo`** in image (DL3004).
- **`COPY --chown`** instead of post-`COPY` `chown` (saves a layer + correct perms).
- Trivy/Grype-style CVE scan: not in scope of this skill, but recommend it as a CI gate.

### 4. Reproducibility
- Pinned base tag at minimum, digest pin ideal.
- Pinned package versions for production images (security trade-off above).
- No `RUN apt-get upgrade` (DL3005) — non-deterministic.
- Build args used for version inputs, not for secrets.

### 5. Runtime hygiene
- `CMD` in JSON exec form, not shell form (DL3025) — proper signal handling.
- `ENTRYPOINT` + `CMD` pattern when args should be overridable.
- PID 1 signal handling: if the app doesn't reap children or handle SIGTERM properly, recommend `tini` or `dumb-init`. Many language runtimes (Node, Python) need this.
- `EXPOSE` documents the port (informational, not enforcement).
- `WORKDIR` set explicitly (DL3000) — not `RUN cd …`.
- Avoid `ENV` of `PATH` mutations that break minimal-base assumptions.
- `SHELL` directive when using `RUN` patterns that need pipefail (DL4006: `SHELL ["/bin/bash", "-o", "pipefail", "-c"]`).

### 6. Supply chain
- BuildKit provenance / SBOM-friendly: recommend `docker buildx build --provenance=true --sbom=true` in CI.
- Reproducible-ish builds: `SOURCE_DATE_EPOCH`, sorted file listings where it matters.
- Base image source trust: official images, verified publishers, or internal mirror. Call out unofficial bases.
- `LABEL org.opencontainers.image.*` for source, revision, version, licenses.

## Output format (inline markdown — do not write to disk)

```markdown
# Dockerfile optimization plan

## Inventory
- `path/to/Dockerfile` — detected stack: <python|node|go|…>, base: `<image:tag>`, multi-stage: <yes/no>
- `path/to/Dockerfile.dev` — …
- `.dockerignore` — present | MISSING

## Findings — severity-grouped

### Critical
For each finding:
- **Title** — one line
- **File**: `path:line`
- **Rule**: Hadolint DL#### / CIS X.Y / Docker best-practice section
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

Brief recap, grouped by the six axes (size / cache / security / reproducibility / runtime / supply chain). Just titles + file refs.

## Quick wins (prioritized order to apply)
1. <highest-leverage change first>
2. …
3. …

## What this Dockerfile already does well
Explicitly list strengths. A plan with no strengths is not credible.
```

## Severity rubric
- **Critical** — secrets in layers, root user in production image, `:latest` in production, public-facing image with no `USER` and no signal handling.
- **High** — large attack surface (full distro base when slim works, no pinning), broken cache discipline making CI builds slow, no `.dockerignore` shipping `.git` into image.
- **Medium** — reproducibility gaps, missing `HEALTHCHECK`, missing `LABEL`s, `ADD` where `COPY` belongs.
- **Low** — style, ordering nits, unpinned non-security packages.

## Non-negotiables
- **Cite rule IDs** for every finding where one applies — Hadolint (DL####), CIS Docker Benchmark (X.Y), or "Docker best-practices: <section>". No hand-waved findings.
- **Always provide a concrete diff** for proposed fixes. No "you should consider…" without showing the change.
- **Don't auto-apply.** This skill produces a plan only — the user (or a separate edit pass) applies the diffs.
- **No org-specific standards** (registry domain, mandatory labels, internal base images) unless the user supplies them in the request.
- **Tailor to detected stack.** Generic advice when you can't tell; specific advice when the stack is obvious.
- **Honesty in strengths.** If the Dockerfile is already good, say so plainly and keep the plan short.
