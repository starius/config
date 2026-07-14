---
name: gcp-spot-runner
description: Explicit-only workflow for running heavy builds, Dockerized compiles, large tests, benchmarks, or long compute jobs on temporary Google Cloud Spot VMs with gcloud. Use only when the user explicitly invokes $gcp-spot-runner or asks for a tmp Google Cloud server, remote machine/server, Spot VM, or similar remote offload; enforces remote execution, cost/resource guards, Nix-first setup, SSH/tmux reuse, result handling, cleanup, and privacy.
---

# GCP Spot Runner

Use only after an explicit remote/cloud offload request. Use `gcloud`; if missing, unauthenticated, or pointed at the wrong project, stop and ask. Never put VM names, IPs, project IDs, zones, credentials, or provider details in commits or non-ignored project files.

## Hard Guards

- Run heavy compilation, Docker builds, large tests, benchmarks, and long compute jobs on the remote VM, not locally. Local commands are only for inspection, sync/setup, and result analysis unless the user permits local execution.
- Before creating anything, count all instances in the active project. If there are 10 or more, do not create a VM.
- At the start, clean up only skill-owned resources: VMs named `codex-spot-<yyyymmddhhmmss>-<rand>` with labels `managed-by=codex,skill=gcp-spot-runner`. Delete stopped skill-owned VMs/disks only when `codex-last-active` metadata or stop time is older than 3 days. Never manage resources missing both the prefix and labels.
- Create only skill-owned Spot VMs: `--provisioning-model=SPOT`, prefix `codex-spot-`, labels `managed-by=codex,skill=gcp-spot-runner`, metadata `codex-last-active=<iso-utc>,codex-run-id=<opaque-id>`, ephemeral external IP only. Prefer auto-delete boot disks; no static IPs, GPUs, TPUs, local SSDs, premium disks, external services, or open firewall rules unless explicitly required.
- Verify the estimated monthly VM plus disk cost is under USD 200 before creation. If current pricing cannot be checked, do not create the VM.
- Pick the cheapest suitable machine: match required architecture; use ARM only if supported; avoid tiny/shared-core types for Docker, large builds, tests, or benchmarks unless clearly sufficient.
- Stop the VM after 5 idle minutes, preserving disk for reuse. Refresh `codex-last-active` while work/chat is active. Delete stopped skill-owned VMs/disks after 3 days. Never leave an unused VM running longer unless explicitly asked.

## Setup

- Use Debian 13. First SSH step: install working multi-user Nix. Prefer `nix shell`, `nix develop`, flakes, and Nix tools over `apt`; use `apt` only for bootstrap.
- Create one private per-session temp dir `/tmp/codex-gcp-<task-slug>/` with mode `0700` for SSH sockets, downloaded summaries/logs, and transient metadata. Derive `<task-slug>` once from the task, like a short branch name (`debug-race-condition-in-funding`); keep it stable for the session and omit secrets, IDs, IPs, zones, and credentials. Never store runner state or artifacts in the worktree.
- After first SSH, use normal `ssh` with ControlMaster plus remote `tmux` session `codex-run`. Keep sockets under the session temp dir and discard them after stop/restart because ephemeral IPs can change.

## Workflow

1. Create/reuse the session temp dir under `/tmp`; keep all local runner state and downloaded summaries/logs there.
2. Prefer resuming a compatible stopped skill-owned VM over creating a new one. Start it, refresh `codex-last-active`, recreate SSH multiplexing because the IP may have changed, attach/create `tmux` session `codex-run`, and print the user attach command again.
3. If no compatible stopped VM exists, create a new one only after all guards pass.
4. Sync only needed source/configuration. Exclude secrets, unnecessary `.git`, caches, dependencies, build outputs, `node_modules`, `target`, `dist`, `bazel-*`, and large binaries.
5. Run heavy commands in `tmux` and tee concise logs/results.
6. Print a user-runnable attach command in chat, e.g. `ssh <alias-or-host> -t 'tmux attach -t codex-run || tmux new -s codex-run'`. Chat may mention host/IP when useful; commits and non-ignored files must not.
7. Use multiplexed SSH to send commands, capture panes, poll status, and sync small results. Avoid repeated `gcloud compute ssh` except for create/start/bootstrap or SSH config regeneration.
8. If stuck from OOM, swapping, or host trouble, reboot/reset once with `gcloud`; if still unhealthy, stop/delete only that skill-owned VM and replace only after re-checking guards.
9. Download small useful artifacts only when needed or before final deletion: summaries, coverage, benchmark JSON/CSV, compressed logs, stats, notes. Do not download binaries/build artifacts unless requested.
10. On idle, stop after 5 minutes. Future invocations handle 3-day cleanup at the start.
