---
name: build-from-requirements
description: Autonomously implement and verify a READY task specification or multi-feature PRD, including planning, dependency ordering, incremental code, tests, independent review, repairs, checkpoints and continuation. Use when given a requirements file path or asked to continuously build a product from an approved spec, especially in Hermes or OpenCode. Do not invent unresolved product requirements or bypass safety/approval gates.
---

# Build from requirements

**Mission:** treat a `READY` requirements document as a bounded product contract and drive the **entire approved scope** to verified completion, across multiple implementation phases when possible, without recurring product clarification questions. The primary is the *builder and acceptance owner*; `orchestrator` only advises on delegation, not overall execution. Read the sibling `../define-task-requirements/references/requirements-contract.md` for the schema and `../define-task-requirements/references/git-workspace.md` for Git-native lifecycle and links. When the skill engine does not resolve relative paths, locate the installed sibling skill directory explicitly rather than guessing. Also use `design-for-change`, `subagent-model-routing`, `checkpointed-analysis` and `cli-subagent-progress-logging` as needed, without reloading full catalogs unnecessarily.

## Invocation and prerequisites
Examples (Hermes installed skills are slash commands; other tools may require an explicit skill invocation):

```text
/build-from-requirements @product/work/requirements/20261118T025017Z-my-product.md
/product-builder @product/work/requirements/20261118T025017Z-my-product.md
/build-from-requirements @product/work/requirements/20261118T024512Z-my-feature.md
```

Resolve `@path` (or plain path) relative to the current repository; never mistake a chat attachment token for a filesystem path without verifying it. Inspect the document, all linked in-scope feature specs, code, version/control state, tests, tools and safety constraints. If `requirements_status` is not `READY` or `delivery_status` is not `READY TO BUILD` / a verified resumable in-flight state, **do not interpret missing product decisions as permission to invent them**; report exact blockers, optionally implement separable READY features, or hand back to `define-task-requirements` / `define-product-requirements`. Recheck that requirements match current repo reality.

## 1. Build the execution graph
Map the PRD's dependency order, interface ownership and acceptance IDs into independently verifiable milestones. One task owns one bounded change and a validation target. Plan sequence, critical path, parallel read-only research, per-phase tests, compatibility, rollback and integration; prefer existing repo conventions and scripts. Use `design-for-change` for real design choices and its versioned worker handoff contract. Do not redesign approved product behavior; choose the smallest coherent implementation consistent with it.

Use the tracked `product/work/build-runs/<requirements-id>/` by default (or an equivalent existing tracked project system), with the canonical requirement and delivery status recorded in the dated spec file. Maintain real Git branch/PR links and a status history in `## Delivery tracking`. Keep transient logs in ignored `.ai/local/` or the repo's established ignored logs directory; the run's status/acceptance/handoff summaries must be visible to the next agent through Git. Never create an invisible record that a future session cannot locate. Record source spec path and hash/revision if available, branch/repo identity, milestone DAG, acceptance coverage, evidence and a single next action.

## 2. Autonomous milestone loop
Repeat until **every in-scope acceptance ID is verified**, a genuine blocker applies to all remaining work, or the current execution environment stops further tool use:

1. **ORIENT:** read `STATE.md`, only relevant feature spec, prior decisions and recent diffs. Check for human/external edits and uncommitted changes (preserve all user-owned work).
2. **SELECT:** choose highest-priority `READY` dependency-unblocked milestone. Never re-run completed verified work without a cause.
3. **IMPLEMENT:** perform a bounded change. The primary implements itself or delegates an explicit, file-owned task to a capable worker. Default one implementation writer; separate worktrees only when verified safe. Contract-first tests and failure paths are preferred.
4. **TEST:** run repo-inspected build/lint/type/unit/integration commands, then risk-based end-to-end/hardware checks. Capture commands, exit codes, meaningful assertions, artifact revisions and evidence; record unrun checks as `UNVERIFIED`, never passed.
5. **REVIEW:** independently challenge the diff using a different agent/model where actually available (code review, architecture, security, or domain specialist as warranted). Review root cause, requirement coverage, regressions, compatibility, trust boundaries and negative cases. A self-review is a fallback **not** an independent review.
6. **REPAIR:** reproduce actionable findings, patch root causes and retest. Limit repeated failed repair loops; after two unproductive cycles, diagnose and split/escalate instead of burning tokens.
7. **ACCEPT:** only the primary reconciles findings and marks a milestone verified against its acceptance IDs. No `PASS` from a compile-only check when runtime/device evidence is required.
8. **CHECKPOINT AND CONTINUE:** write phase results, new risks, changes, tests, reviewer verdict, fix history, next ready task and concise handoff. Update `delivery_status`, the timestamped status history, and verified branch/PR URLs in the dated requirements file as transitions occur. Commit changes and tracked checkpoint artifacts when permitted, with clear scope. **Checkpointing is not task completion.** Continue to the next milestone in the same session.

Never stop merely because one phase, PR, patch, or handoff is done. Do not invent a process that survives a chat/session timeout: when compaction is available, invoke its *verified native mechanism* only after checkpointing; otherwise use the handoff in the next user/agent session. No arbitrary self-respawn or invisible background job claims.

## 3. Exception policy: minimize questions without guessing
- **Technical ambiguity with stable product behavior:** inspect code/docs/tests, select a documented reversible implementation, verify the contract, continue.
- **Recoverable infra/tool failure:** record cause, perform bounded retries or independent ready work, then escalate if persistent.
- **New product-level decision, unsafe action or spec contradiction:** record an explicit `CHANGE_REQUEST` with alternatives, risk, dependency impact and a recommended choice. Freeze only affected milestones; continue unrelated READY tasks. Never silently select authentication/privacy/payment/irreversible behavior.
- **External approval or unavailable physical device:** mark the acceptance `BLOCKED_EXTERNAL` or `UNVERIFIED` with the exact validation procedure. Do not falsely complete the product.
- **Production data, deployments, destructive Git and security-sensitive external effects:** follow the user's explicit authorization and repository safety rules; a READY PRD does not automatically grant operational permission.

## 4. Durable state and resumption
Use [references/build-state.md](references/build-state.md) and the sibling Git-workspace reference. The single-writer primary maintains `STATE.md`, `PHASE_LOG.md`, `ACCEPTANCE.md`, `DECISIONS.md`, and `HANDOFF.md`. Subagents return short evidence digests with changed paths and exit codes; the primary writes canonical state. Persist semantic checkpoints after each milestone and before likely context compaction; do not serialize hidden reasoning or dump logs into context. On resume, compare requirements identity and checkout revision, revalidate claimed completions and read the handoff *before* choosing the next step.

## 5. Completion gate
Output `COMPLETE` **only when** all in-scope acceptance IDs are verified with the specified evidence, integration boundaries work, consequential review findings are resolved, relevant tests run, and there are no unacknowledged blockers. Otherwise report `PARTIAL` or `BLOCKED` with the exact next action and link to the durable handoff. A successful handoff, green subset of tests, or merged PR is not equivalent to completed product acceptance.
