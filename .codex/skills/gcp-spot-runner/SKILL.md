---
name: gcp-spot-runner
description: Explicit-only workflow for running heavy builds, Dockerized compiles, large tests, benchmarks, or long compute jobs on temporary Google Cloud Spot VMs with gcloud. Use only when the user explicitly invokes $gcp-spot-runner or asks for a tmp Google Cloud server, remote machine/server, Spot VM, or similar remote offload; enforces remote execution, local-source authority, cost/resource guards, Nix-first setup, SSH/tmux reuse, result handling, cleanup, and privacy.
---

# GCP Spot Runner

Use only after an explicit remote/cloud offload request. Use `gcloud`; if missing, unauthenticated, or pointed at the wrong project, stop and ask. Never put VM names, IPs, project IDs, zones, credentials, or provider details in commits or non-ignored project files.

## Hard Guards

- Run heavy compilation, Docker builds, large tests, benchmarks, and long compute jobs on the remote VM, not locally. Local commands are only for inspection, sync/setup, and result analysis unless the user permits local execution.
- The local worktree is authoritative for source. Treat remote source copies as disposable execution caches. Prefer editing locally; if source files change remotely, bring those source changes back to the local worktree immediately and re-sync local-to-remote before continuing. Never leave source changes only on a remote VM or stopped disk.
- One Codex session gets one VM. Once this session chooses or creates a VM, pin its exact name, zone, and `codex-run-id`; that identity is authoritative for the rest of the session. Never substitute another running VM, including one with the same task slug or a compatible shape, unless the user explicitly asks to reuse that specific machine.
- Always inspect the pinned current-session VM before considering creation or other VMs. If it is `TERMINATED`, start that exact VM and resume it; Spot termination is not permission to switch machines. If it is transitioning, wait/recheck. Only enter the creation path if the pinned VM does not exist or this session has not selected one.
- Before creating anything, count all instances in the active project. If the count is below 10, continue. If it is 10 or more, consider only stopped (`TERMINATED`) skill-owned VMs other than the current-session VM: require the name prefix plus all ownership labels, sort by GCE `lastStopTimestamp` ascending, and select exactly the oldest. Delete that VM and its auto-delete disk only if it has been stopped for at least 24 hours, then recount. If no eligible VM exists or the count remains 10 or more, do not create a VM.
- At the start, clean up only skill-owned resources: VMs named `codex-spot-<task-slug>-<rand>` with labels `managed-by=codex,skill=gcp-spot-runner,task-slug=<task-slug>`. Exclude the pinned current-session VM. Outside the capacity rule above, delete stopped skill-owned VMs/disks only when `codex-last-active` metadata or `lastStopTimestamp` is older than 3 days. Never manage resources missing either the prefix or any ownership label.
- Create only skill-owned Spot VMs: `--provisioning-model=SPOT`, name `codex-spot-<task-slug>-<rand>`, labels `managed-by=codex,skill=gcp-spot-runner,task-slug=<task-slug>`, metadata `codex-last-active=<iso-utc>,codex-run-id=<opaque-id>`, ephemeral external IP only. Keep `<task-slug>` short, lowercase, and GCE-name-safe. Prefer auto-delete boot disks; no static IPs, GPUs, TPUs, local SSDs, premium disks, external services, or open firewall rules unless explicitly required.
- Use the Fast Machine Table when the task fits; it counts as pre-collected cost verification. Otherwise verify current monthly VM plus disk cost is under USD 200 before creation; if current pricing cannot be checked, do not create the VM.
- Pick the cheapest suitable machine: match required architecture; use ARM only if supported; avoid tiny/shared-core types for Docker, large builds, tests, or benchmarks unless clearly sufficient.
- Stop the VM after 5 idle minutes, preserving disk for reuse. Refresh `codex-last-active` while work/chat is active. Delete stopped skill-owned VMs/disks after 3 days. Never leave an unused VM running longer unless explicitly asked.

## Fast Machine Table

Use these `us-central1`/Americas Linux Spot defaults first; prices collected 2026-07-15 from Google Cloud Billing SKUs, using 730 h/mo and <=100 GB balanced PD (~$10/mo). If a row fits, skip live price hunting and only check quota/availability.

| Use | Arch | Machine | VM $/mo | With 100 GB PD |
| --- | --- | --- | ---: | ---: |
| small/normal build/test | amd64 | `c3-standard-4` 4 vCPU/16 GB | $34 | $44 |
| medium build/test | amd64 | `c3-standard-8` 8 vCPU/32 GB | $69 | $79 |
| large build/test, near cap | amd64 | `c3-standard-22` 22 vCPU/88 GB | $189 | $199 |
| small/normal ARM-safe | arm64 | `t2a-standard-4` 4 vCPU/16 GB | $44 | $54 |
| medium ARM-safe | arm64 | `t2a-standard-8` 8 vCPU/32 GB | $87 | $97 |
| large ARM-safe | arm64 | `t2a-standard-16` 16 vCPU/64 GB | $174 | $184 |
| faster ARM medium | arm64 | `c4a-standard-8` 8 vCPU/32 GB | $108 | $118 |

If C3 is unavailable, fall back to `n2-standard-4` (~$71/mo with disk) or `n2-standard-8` (~$132/mo with disk). Do not use `c3-standard-44+`, `t2a-standard-32+`, or `c4a-standard-16+` under the $200/month cap without fresh pricing and explicit approval.

## Setup

- Use Debian 13. First SSH step: install working multi-user Nix. Prefer `nix shell`, `nix develop`, flakes, and Nix tools over `apt`; use `apt` only for bootstrap.
- Create one private per-session temp dir `/tmp/codex-gcp-<task-slug>/` with mode `0700` for SSH sockets, downloaded summaries/logs, and transient metadata. Derive `<task-slug>` once from the task, like a short branch name (`debug-race-condition-in-funding`); keep it stable for the session and omit secrets, IDs, IPs, zones, and credentials. Never store runner state or artifacts in the worktree.
- After first SSH, use normal `ssh` with ControlMaster plus remote `tmux` session `codex-run`. Keep sockets under the session temp dir and discard them after stop/restart because ephemeral IPs can change.

## Workflow

1. Create/reuse the session temp dir under `/tmp`; keep all local runner state and downloaded summaries/logs there. Once a VM is chosen, store its exact name, zone, and `codex-run-id` in the current session's transient state and do not replace that identity merely because the VM stops.
2. Resolve the exact pinned current-session VM first. Reuse only it, or a specific skill-owned VM the user explicitly asks to reuse. Do not infer VM reuse from instance listings, an existing temp dir, a compatible shape, a shared slug, or another running VM.
3. Inspect the pinned VM's status. If `TERMINATED`, run `gcloud compute instances start` on that exact name and zone. If running, continue with it. Refresh `codex-last-active`, recreate SSH multiplexing because the IP may have changed, attach/create `tmux` session `codex-run`, and print the user attach command again. Create a replacement only if the pinned VM no longer exists, and only after the capacity and other creation guards pass.
4. Sync only needed source/configuration from local to remote. Exclude secrets, unnecessary `.git`, caches, dependencies, build outputs, `node_modules`, `target`, `dist`, `bazel-*`, and large binaries.
5. Run heavy commands in `tmux` and tee concise logs/results. If a remote command edits source/configuration, immediately copy back only those source changes, inspect/apply them locally without overwriting unrelated local edits, then sync local-to-remote again.
6. Print a user-runnable attach command in chat, e.g. `ssh <alias-or-host> -t 'tmux attach -t codex-run || tmux new -s codex-run'`. Chat may mention host/IP when useful; commits and non-ignored files must not.
7. Use multiplexed SSH to send commands, capture panes, poll status, and sync small results. Avoid repeated `gcloud compute ssh` except for create/start/bootstrap or SSH config regeneration.
8. If stuck from OOM, swapping, or host trouble, reboot/reset once with `gcloud`; if still unhealthy, stop/delete only that skill-owned VM and replace only after re-checking guards.
9. Download small useful artifacts only when needed or before final deletion: summaries, coverage, benchmark JSON/CSV, compressed logs, stats, notes. Do not download binaries/build artifacts unless requested.
10. On idle, stop after 5 minutes. Future invocations handle 3-day cleanup at the start.
