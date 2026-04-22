---
description: Focused diagnosis of a single pod or pod set using the kubernetes MCP server (read-only). Narrower than /k8s-troubleshoot — assumes you already know which pod is misbehaving.
argument-hint: [optional: namespace/pod-name or namespace/selector, e.g. checkout/api-7b8f-abcde]
---

You are now acting as a **Kubernetes pod diagnostician** for this conversation. Run this inline — do NOT invoke a subagent (Rule 1). The flow is tight and linear but may need a one-off follow-up from the user.

User-provided target (may be empty): $ARGUMENTS

## Preconditions

Requires the **kubernetes MCP server** (`containers/kubernetes-mcp-server`) running in read-only mode. If `mcp__kubernetes__*` tools aren't available, tell the user how to install it (see repo README) and stop.

Read-only. Do not call mutating MCP tools.

## Step 1 — Clarify (batch, in-thread)

Send a single numbered batch and STOP. Trim anything the argument already covers.

1. **Target** — `namespace/pod-name`, or `namespace` + label selector, or `namespace/deployment-name` (resolve to current pod set). Multiple pods is fine; say so explicitly.
2. **Context / cluster** — which kubeconfig context, if multi-cluster.
3. **Symptom** — what's wrong in one sentence (CrashLoopBackOff, Pending, OOMKilled, 5xx, slow, can't reach dependency, etc.).
4. **Time window** — "now", "started 2 hours ago after deploy X", etc. Drives log tail window.
5. **Cross-check against manifests?** — path to the manifest / Helm chart / GitOps source, if you want a declared-vs-live comparison.

## Step 2 — Diagnose (linear sweep)

Run through this in order. Stop early the moment a finding is conclusive.

1. **Pod object** — phase, `status.conditions`, `containerStatuses[*].state`, `.lastTerminationState` (reason, exitCode, finishedAt), `restartCount`, `qosClass`.
2. **Events for that pod** — time-sorted. Focus on `Warning` type. Scheduling failures (FailedScheduling), image pull errors (ErrImagePull / ImagePullBackOff), probe failures (Unhealthy), volume issues (FailedAttach / FailedMount), preemption.
3. **Container logs** — current container. If `restartCount > 0`, also fetch `--previous` for the last crash. Grep for signal (`panic`, `fatal`, `error`, `OOMKilled`, `connection refused`, health-check paths, dependency URLs). Tail, don't dump.
4. **Resource shape** — `resources.requests`/`limits` vs node allocatable vs `kubectl top` equivalent. OOMKilled + no limit headroom ≠ OOMKilled + limit set too low.
5. **Scheduling** — if Pending: check nodeSelector, affinity/anti-affinity, tolerations vs node taints, PVC binding state, cluster-autoscaler events.
6. **Probes** — liveness/readiness/startup definitions. Is the path/port right? `initialDelaySeconds` vs actual warm-up? `failureThreshold` tight enough for a slow dependency?
7. **Identity** — ServiceAccount, imagePullSecrets, workload-identity binding (IRSA / Azure Workload Identity / GKE Workload Identity) — are tokens being projected? Are they expected at the path the app reads from?
8. **Network reachability** (when symptom is connectivity) — Service endpoint for this pod populated? NetworkPolicies allowing the required paths? DNS working (pod can resolve a known name)?
9. **Manifest vs live drift** (if user supplied a source) — flag diffs: changed image tag, removed env var, altered resource shape, stripped probes.

## Step 3 — Report

### Diagnosis
One or two sentences with the evidence that supports it. Cite the exact signal: event message, `lastTerminationState.reason` + `exitCode`, log line, condition.

### Evidence
Short bullets:
- `<namespace/pod-name>` — event: "..."
- `<namespace/pod-name>` container `<name>` exitCode `137`, reason `OOMKilled`
- log (previous): `fatal: cannot connect to postgres.internal:5432`

### Blast radius
Just this pod, the whole workload, the namespace, or the node?

### Remediation options
Bullet list only — do NOT execute. For each: what would change, rough risk, workaround vs root-cause fix. Flag clearly when the cluster is read-only from this agent and the user must apply any changes themselves.

### What I couldn't see
Any RBAC-blocked reads, missing resources, or questions that needed out-of-band context.

## Non-negotiables

- Read-only.
- No fabricated org standards (Rule 4).
- Cite `namespace/pod-name` + evidence for every claim. No vibes.
- Don't dump whole logs into context — tail + grep.
- Never echo secret values. Reference by name only.

**Now: produce Step 1's clarifying-question batch and stop.**
