---
name: database-migration
description: Plan, implement, or review database schema/data migrations, backfills, index changes, constraint changes, or persisted-format evolution. Use when changing tables, columns, indexes, constraints, large datasets, ORM mappings, or when zero-downtime rollout/rollback and mixed-version compatibility matter. Skip for trivial typos/renames/one-line copy fixes.
---

# Database migration

Goal: change persisted state safely across application versions, data volumes, failures, and rollback.

## 1. Establish current state

Inspect:
- actual schema/migration history,
- ORM/query code,
- constraints/defaults/nullability,
- indexes/query paths,
- writers/readers/consumers,
- data volume/distribution if available,
- deployment topology and version coexistence.

Do not design from model/entity classes alone when the DB schema is source of truth.

## 2. Define invariants and compatibility

State:
- old and new data invariants,
- which app versions must read/write during rollout,
- default/missing/legacy value semantics,
- whether rollback must remain possible after new writes.

Prefer additive changes and expand → migrate/backfill → switch reads/writes → enforce → contract.

## 3. Schema changes

For each DDL change consider:
- lock duration/blocking behavior for the actual DB/version,
- table rewrite risk,
- index creation mode,
- validation of new constraints,
- null/default semantics,
- replication/transaction-log pressure,
- deploy sequencing.

Use Context7 or Tavily only to verify external DB/ORM/version-specific behavior, then relate it back to the actual schema and runtime.

## 4. Backfills/data migrations

Design backfills to be:
- idempotent/restartable,
- bounded/batched,
- observable,
- safe under concurrent application writes,
- resumable after failure,
- explicit about ordering and checkpoints.

Avoid a single unbounded transaction over large production data.

Define how to detect completion/corruption and how to recover.

## 5. Read/write transition

When schemas/formats coexist, specify:
- dual-read/dual-write behavior if needed,
- precedence when old/new fields disagree,
- when writers can switch,
- when readers can require new data,
- when old columns/formats can be removed.

Do not contract until all consumers are compatible and data migration is verified.

## 6. Index/query changes

Validate query shape and index utility against actual predicates/order/join behavior. Consider write amplification, uniqueness, nullable semantics, and online/concurrent index creation support.

## 7. Rollback

Define rollback for each rollout phase. Ask specifically: after the new application has written new-format data, can the old application still run safely?

If rollback becomes one-way after a phase, make that explicit and require a deliberate gate.

## 8. Testing

Test migrations against realistic old schemas/data:
- empty/populated/legacy/null edge cases,
- upgrade path,
- application reads/writes during transitional schema,
- constraint/index behavior,
- rollback where supported,
- idempotent/restart behavior for backfills.

Use a disposable DB/Testcontainer when repository conventions support it. Never run destructive migration commands against unknown/persistent environments to validate a change.

## 9. Final gate and migration plan

Apply the universal quality gate and additional plan gate from `00-core-global`.

Return an ordered rollout with: preconditions, migration steps, app deploy sequencing, backfill/checkpoints, validation queries/metrics, rollback gates, final cleanup/contract step. Adversarially review locking, mixed versions, partial completion, concurrent writes, retries, and rollback.
