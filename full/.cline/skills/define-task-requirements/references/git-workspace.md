# Git-native requirements workspace (v1)

**Use this when requirements need to survive across agents, branches or sessions.** The default `product/work/` is a **committed, reviewable project artifact**, not an ignored agent scratch directory. Reserve `.ai/` for transient/private analysis and logs. Keep the source of truth inside the target Git repository, without assuming Shortcut, GitHub Issues, Notion or a third-party task service exists.

## Directory and naming

```text
<target-repo>/
  product/work/
    README.md                         # copy concise process rules and ownership
    requirements/
      20261118T024512Z-device-session-recovery.md
      20261118T025017Z-local-console-platform.md
      20261118T025101Z-lobby-host-migration.md
    build-runs/
      FEATURE-001/
        STATE.md
        PHASE_LOG.md
        ACCEPTANCE.md
        HANDOFF.md
```

Create `product/work/requirements/` and `product/work/build-runs/` only when there is substantial or persistent work. The parent repository's `.gitignore` must NOT ignore `product/work/`—check before writing, and do not override an intentional ignore without approval. Keep transient logs, secrets and private diagnostics outside tracked files (e.g. ignored `.ai/local/`). If a repo already has a tracked, equivalent documented workflow, adapt rather than creating a duplicate system.

**File name:** `YYYYMMDDTHHMMSSZ-kebab-case-task-name.md`, UTC, using a source-verified clock (e.g. `date -u +%Y%m%dT%H%M%SZ` if shell is available). If no clock is accessible, request/gather a trusted timestamp, rather than pretending to know UTC. Sanitize the slug to ASCII lowercase letters, digits and dashes. If a filename already exists, append an incrementing suffix before `.md`. Never rename a tracked requirement because its status changed; links and IDs remain stable. Product PRDs and feature specifications **both** follow this naming pattern. Link features from the product PRD's feature index using relative filenames. Cross-repository products should have one canonical PRD in the coordinator repo and feature files near their owning code, with stable URLs/refs, avoiding competing masters.

## Two independent state dimensions

The **requirements contract** and **delivery workflow** are different dimensions; keep both in machine-readable frontmatter:

```yaml
---
requirements_schema_version: 1
kind: feature
id: FEATURE-001
requirements_status: DRAFT
delivery_status: DEFINING
parent_product: none
---
```

- `requirements_status`: `DRAFT` | `READY` | `SUPERSEDED`. READY means product decisions and acceptance are decision-complete, not that any code exists.
- `delivery_status`: `DEFINING` | `READY TO BUILD` | `IN PROGRESS` | `READY FOR REVIEW` | `TESTING` | `COMPLETE` | `BLOCKED`. Status labels are human-readable; quote multiword values in YAML.

A requirements author may set READY only after the explicit requirements gate; then set delivery to READY TO BUILD. A builder must verify both (READY and READY TO BUILD or a documented resumable active status) before starting. COMPLETE requires actual evidence for all in-scope acceptance criteria, not merely PR creation, tests scheduled, or a status change.

A valid workflow normally progresses:
`DEFINING -> READY TO BUILD -> IN PROGRESS -> READY FOR REVIEW -> TESTING -> COMPLETE`.
A team's real process may reverse REVIEW/TESTING or revisit steps after findings; retain history and evidence. BLOCKED can interrupt any incomplete stage, but records the previous status, exact blocker, owner and unblocking criterion. Reopening COMPLETE is allowed with a documented reason and invalidation of outdated verification.

Do not use `requirements_status` for progress tracking or `delivery_status` to bypass the READY gate. A user-approved requirement amendment reopens DRAFT as needed, changes tests and affected feature contracts, and re-verifies dependent work.

## Status and Git links section

Every requirement document must contain **exactly one** `## Delivery tracking` section:

```markdown
## Delivery tracking
The canonical current statuses are in frontmatter.

- **Primary owner:** <agent or human/none>
- **Current blocker:** None
- **Next action:** <concrete, bounded action>
- **Branches:** [feature/device-session-recovery](https://github.com/ORG/REPO/tree/feature/device-session-recovery)
- **Pull requests:** [#23](https://github.com/ORG/REPO/pull/23)
- **Related requirements:** [FEATURE-002](20261118T025101Z-lobby-host-migration.md)
- **Acceptance evidence:** [ACCEPTANCE.md](../build-runs/FEATURE-001/ACCEPTANCE.md)

### Status history
| UTC timestamp | From | To | Actor | Evidence / reason |
|---|---|---|---|---|
| 2026-11-18T02:45:12Z | DEFINING | READY TO BUILD | requirements author | READY gate checked |
```

Use **actual** branch/PR links from Git commands/API; do not fabricate PR numbers or links. If not created, use `None yet`. Keep status history compact and append-only; if large, move old events into `build-runs/<ID>/PHASE_LOG.md` and link them. Never silently set COMPLETE or delete records of a blocker.

## Single-writer and multi-repository semantics

The designated primary agent updates canonical frontmatter, status history and acceptance; workers return evidence and proposed edits. Every status transition is committed with a meaningful Git commit where the current workflow permits; status is not complete until persisted, and a local uncommitted edit must be reported as such. Never overwrite uncommitted user changes. If separate branches edit the same requirement, reconcile decisions and statuses before merging; the highest-looking status does not automatically win. In a multi-repo system, record the exact code revision corresponding to acceptance, and link cross-repo PRs, tests and integration baselines.

## Status semantics and evidence

| Status | Meaning / gate |
|---|---|
| DEFINING | Requirements, decisions and acceptance still being refined |
| READY TO BUILD | Requirements READY, reviewer challenge resolved, dependencies feasible |
| IN PROGRESS | Implementation work started in scoped branch/worktree |
| READY FOR REVIEW | Implementation change submitted for substantive review with initial test evidence |
| TESTING | Required tests and integration/device checks being executed or evidence being collected |
| COMPLETE | Every in-scope AC VERIFIED; review findings resolved; links/revisions recorded |
| BLOCKED | Named blocker and owner, criteria to resume; unrelated ready work may continue |

Make the tracked requirement readable by a new agent with *no conversational history*. Keep it as the controlling prompt; add more detailed phase evidence in build-runs rather than bloating the requirement's prose.
