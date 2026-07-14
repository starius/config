---
name: bug-hunter
description: Explicit-invocation-only workflow for hunting high-confidence bugs, suboptimal decisions, dominated strategies, bad state transitions, and root causes in software systems. Use only when the user explicitly invokes $bug-hunter or asks for bug hunting, empirical/static bug search, suboptimal decision search, dominated strategy search, transition-table analysis, or similar deep defect-finding work.
---

# Bug Hunter

Use this skill only after an explicit user request for deep bug hunting; do not use it for ordinary implementation, quick fixes, or routine review.

## Goal

Find decisions or transitions where the system chose a worse action while an equal-or-higher-ranked action was available. Build a mental transition table, then validate suspicious paths empirically.

Priority ranking, highest first; tailor names to the system:

1. Safety/correctness: never risk, lose, or corrupt the system's own assets or data.
2. Do not harm the counterparty/user: never take or endanger what is theirs.
3. Do not crash the process.
4. Do not fail important operations or degrade availability.
5. Prefer cheap, normal, cooperative paths over expensive, fallback, or last-resort paths when higher rules are equal.

## Method

- Start static: inspect diffs, state machines, queues, retries, locks, ownership, persistence, error paths, fallback paths, and boundary checks. Identify decision points, possible alternatives, and invariants.
- Go empirical: run the real system or closest harness. Exercise normal paths plus non-trivial edge cases: injected errors, restarts, races, stale state, timeouts, slow/transient backends, partial writes, duplicate events, and concurrency.
- Instrument decision points when needed. Capture exact state: inputs, stored state, available alternatives, branch taken, outcome, timing, and errors.
- Flag a decision only when a higher-ranked action was available but not taken, or when the chosen transition violates an invariant.
- Trace each high-confidence finding back to root cause in code. Re-run or construct a scenario where the issue must manifest before reporting.

## Reporting

Report a few strong findings before many weak ones. For each finding include: file/line, violated priority or invariant, the better available action, reproduction/trace evidence, root cause, user/system impact, and the smallest plausible fix or test. Say clearly when no high-confidence issue was found and name the remaining coverage gaps.
