# Durable autonomous build state (v1)

Use project conventions first. A recommended layout for a run is:

```text
.ai/work/build-runs/<requirements-id>/
  STATE.md         # concise single-writer current state and next action
  PHASE_LOG.md     # append milestone outcomes; no raw full logs
  ACCEPTANCE.md    # one row per AC ID; status and evidence
  DECISIONS.md     # technical design decisions, change requests
  HANDOFF.md       # restartable digest for a new session/context
  # raw logs belong in ignored .ai/local/; do not commit secrets
```

By default `.ai/work/` is tracked; verify it is not ignored and the status/handoff summaries are committed before expecting another checkout/agent to see them. If the repository already has a tracked alternative, use that consistently. Keep local logs, secrets and large diagnostic files out of Git. Never overwrite user notes or commit secrets/logs. Only the primary writes canonical ledger files.

## STATE.md must contain
- Spec path, ID, **requirements_status** and **delivery_status**, known commit/hash; repo and exact branch/HEAD/worktree.
- Objective and current phase; dependency graph (ready, blocked, verified).
- Verified facts, interfaces/invariants, affected files, outstanding findings and human decisions.
- Next **one** executable action with validation command or research target.
- Constraints and commands that must not be run without approval.

## ACCEPTANCE.md must contain
`| AC ID | Feature | Status | Evidence path/command | Revision | Notes |`

Allowed statuses: `PENDING`, `IN_PROGRESS`, `VERIFIED`, `FAILED`, `UNVERIFIED`, `BLOCKED_EXTERNAL`. A status is `VERIFIED` only if the actual spec-prescribed evidence was observed, with executable command/exit code and meaningful assertions or a documented physical/manual run. Recheck evidence after changes to affected contracts.

## PHASE_LOG.md: one record per phase
Phase ID, requirements IDs, base/head revisions, changed files, tests/commands with exits, reviewer identity and whether independent, findings, repairs, unverified assertions, decisions, and completion verdict. Include logs by path, not giant raw blocks.

## HANDOFF.md: compact restart contract
1. **Why/where:** repo, branch, worktree, spec path/ID/revision and baseline.
2. **Done:** verified phases/AC IDs and evidence; do not relabel unverified.
3. **Pending:** next ready task, owned files, exact contracts, deps, and acceptance.
4. **Risks:** unresolved findings, blocked external checks, non-negotiable safety conditions.
5. **How to continue:** commands *inspected from this repo*, relevant docs, next action, any requested model/effort and budget.
6. **Integrity check:** compare working tree, spec and branch SHA before any edit; reconcile drift.

## Loop and compaction
After a verified phase: update these documents **and the original dated spec file's delivery metadata, Git links and status history**, persist commits where authorized, read the next pending item, and continue. If native context compaction is available, record state first and use the real supported command/tool; if not, hand off to a new session from `HANDOFF.md`. Checkpointing never proves that automation will survive a process/session end.
