# Requirements contract (schema v1)

This contract is shared by `define-task-requirements`, `define-product-requirements`, and `build-from-requirements`. The authoring agent writes complete requirements, not code-level implementation instructions disguised as requirements. For tracked file names, delivery lifecycle, timestamps, branch/PR links and audit history see [git-workspace.md](git-workspace.md).

## Required metadata

At the start of each requirements document use this literal, plain YAML frontmatter (no YAML library is required for the companion validator):

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

For an umbrella PRD use `kind: product`, `id: PRODUCT-001`, `parent_product: none`. **Requirements** status values are `DRAFT`, `READY`, `SUPERSEDED`; **delivery** status is separately tracked as `DEFINING`, `READY TO BUILD`, `IN PROGRESS`, `READY FOR REVIEW`, `TESTING`, `COMPLETE`, or `BLOCKED`. Follow [git-workspace.md](git-workspace.md) for transitions and the required delivery tracking section. Each feature within a product uses the umbrella product ID for `parent_product`. When READY, preserve a stable ID; an approved changed requirement must update its acceptance, tests, and decision log, and dependent features must be rechecked. No silent scope creep.

## Required sections and meaning

Both product and feature documents use the headings below; explicitly write `Not applicable — reason` where a heading genuinely does not apply rather than leaving an empty placeholder.

1. `## Objective and users`: who, the problem, expected measurable outcomes, current vs target state.
2. `## Scope and non-goals`: in/out, MVP vs deferred, precise boundary and precedence.
3. `## Behavioral scenarios`: actors, preconditions, actions, outputs, errors/retries/cancel/recovery and state transitions. Include representative examples and edge cases.
4. `## Interfaces and data`: APIs/events/schemas/ownership/authentication, storage/retention, integration contracts, versioning. Product PRDs additionally describe cross-feature seams.
5. `## Quality and constraints`: security/privacy, platform, performance budgets and conditions, accessibility, reliability, operating cost, rollout/rollback and invariants.
6. `## Acceptance criteria`: stable `AC-<ID>` clauses, concrete expected result and negative/failure cases; mapping from each criterion to automated test, integration check, hardware validation, or explicit manual evidence.
7. `## Verification strategy`: required environments, fixtures, evidence, baseline, feature and end-to-end test plan. Commands must be inspected if claiming they exist.
8. `## Dependencies and delivery`: gates, cross-feature dependencies, rollout steps, delegated decision boundaries. The product PRD contains a feature index described below.
9. `## Decisions and defaults`: decision ID, user-authorized vs safe-default vs inferred, alternatives, why and impact; include known constraints and deferred choices.
10. `## Open gaps`: `None blocking` only after reviewing known ambiguities; otherwise gap ID, category, owner, impact and next question/research target.
11. `## Delivery tracking`: owner, current blocker/next action, real branch/PR links or `None yet`, related specs, acceptance evidence and timestamped status history. Frontmatter is authoritative for the current statuses.

## Product feature index

A product document MUST contain exactly one feature index section with a Markdown table:

```markdown
### Feature index
| Feature ID | Requirements path | Depends on | Status |
|---|---|---|---|
| FEATURE-001 | 20261118T024512Z-session-recovery.md | none | READY |
| FEATURE-002 | 20261118T025101Z-lobby-migration.md | FEATURE-001 | READY |
```

Paths are relative to the PRD file's directory and must point to real files. A `READY` umbrella PRD requires every in-scope MVP feature indexed as `READY` and its file `requirements_status: READY`, and defined end-to-end integration acceptance across feature boundaries. Deferred features must be explicitly outside MVP and cannot be advertised as READY. No dependency cycles.

## READY gate: no product clarification needed by builder

- In-scope choices with materially different product outcomes have an explicit, user-authorized decision. Do not treat default-by-silence as approval.
- Boundaries include error and recovery paths and authorization rules.
- Every important outcome has observable, falsifiable acceptance criteria and a verification plan.
- Known technical uncertainties are classified as bounded build-time research or blockers, rather than unknowingly passed as missing requirements.
- Product PRD features are READY and integrated with consistent interfaces and sequencing.
- No unresolved `BLOCKING_PRODUCT_DECISION` / contradictory requirement in the document or linked in-scope features.
- A reviewer uninvolved in writing it can answer: *What exactly should the builder deliver and how can it prove it?*

## Suggested feature example (abbreviated; expand for real work)

```markdown
---
requirements_schema_version: 1
kind: feature
id: FEATURE-001
requirements_status: READY
delivery_status: "READY TO BUILD"
parent_product: PRODUCT-001
---
## Objective and users
A player can resume a paused local match after a process restart.
## Scope and non-goals
In: same-device resume of last verified snapshot. Out: transfer between devices.
## Behavioral scenarios
Given verified snapshot S, when app restarts, then user sees Resume and restoring S resumes exactly once.
Given truncated snapshot, when app starts, then do not resume it; show safe new-match option.
## Interfaces and data
Snapshot version is validated before state mutation; existing game state remains authoritative.
## Quality and constraints
No corrupted snapshot can update the live game. Recovery writes are atomic.
## Acceptance criteria
- AC-F001: Valid snapshot restores once, asserted by integration test.
- AC-F002: Truncated snapshot is rejected without mutating state, asserted by corruption test.
## Verification strategy
Automated persistence integration tests; manual restart test on target device; record evidence.
## Dependencies and delivery
No feature prerequisites.
## Decisions and defaults
DEC-01 (user decision): local-only resume; cross-device transfer deferred.
## Open gaps
None blocking.
## Delivery tracking
The canonical current statuses are in frontmatter.
- **Primary owner:** Feature author
- **Current blocker:** None
- **Next action:** implement FEATURE-001
- **Branches:** None yet
- **Pull requests:** None yet
- **Related requirements:** PRODUCT-001
- **Acceptance evidence:** Not started
### Status history
| UTC timestamp | From | To | Actor | Evidence / reason |
|---|---|---|---|---|
| 2026-11-18T02:45:12Z | DEFINING | READY TO BUILD | Feature author | Requirements READY gate checked |
```

Do not declare the *example* READY in actual work without verifying it is complete for the actual product. The companion validator checks structural readiness, not semantic completeness, so the reviewer gate remains essential.
