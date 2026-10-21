---
name: transactional-outbox
description: Design, implement, or review a transactional outbox when database changes and eventual event/message publication must commit together. Use for dual-write gaps, relay crash recovery, duplicate delivery, per-aggregate ordering, consumer deduplication, or outbox rollout/operations. Skip local callbacks, best-effort notifications, and systems without the required shared transaction boundary; outbox does not guarantee exactly-once external effects.
---

# Transactional outbox

Goal: commit business state and durable publication intent atomically, then deliver that intent with explicit duplicate and recovery semantics.

## 1. Verify the dual-write requirement

Respect the requested mode. Inspect the actual database/ORM transaction boundary, business write, publisher, broker/client guarantees, consumers, migrations, and operational jobs. Show the failure gap between committing state and publishing, or publishing and rolling back.

Use an outbox only when eventual publication must follow a committed change. Compare an existing transactional integration/CDC mechanism, an already durable job system, a direct local notification, or best-effort delivery when those meet the contract. An in-memory after-commit callback alone leaves a crash gap. An outbox in a different database or transaction from the domain write does not solve atomicity.

## 2. Define the durable contract

- Commit the business mutation and publication-intent row together in the same verified local transaction. Rollback must remove both. Do not perform broker I/O inside that transaction as though it were a shared atomic commit.
- Use stable event identity and a versioned envelope/payload. Define event type, aggregate/tenant identity, sequence/version where needed, destination, creation time, trace metadata, and only the data consumers require. Verify actual names/schema rather than copying an illustrative schema blindly.
- State ordering scope: per aggregate/key, partition, or none. IDs/timestamps alone may not represent commit order; define sequence allocation and relay/consumer behavior that enforce the required order.
- Define delivery as at-least-once under stated storage, relay, broker, and retry assumptions. Consumers must tolerate duplicates; do not promise exactly-once business effects across independent systems.
- Specify unknown fields/event versions, mixed producer/consumer deployments, retention, sensitive payload handling, and rollback after new-format rows exist.

## 3. Design relay ownership and crash recovery

- Choose existing polling or CDC infrastructure from evidence. Poll bounded batches with suitable indexes; avoid unbounded scans and long-held domain locks.
- Multiple relay workers need an atomic claim/lock or lease protocol verified against the database. Define claim expiry, ownership token/fencing for completion updates, and stale-worker behavior. Lease expiry may still permit duplicate sends; consumers remain duplicate-safe.
- Publish with the stable event ID and wait for the broker's documented durable acknowledgement. Mark delivered only afterward. A crash between acknowledgement and marking causes a repeat, which is expected.
- Never mark delivered before send or delete pending rows merely to clear a backlog. Keep failed/poison events discoverable; define retry/backoff, attempt limits or escalation, parking, and controlled replay using `idempotency-and-retries`.
- If strict order is required, prevent a later event for the same key from overtaking an earlier retried/parked event, or define an explicit gap policy. Parallel claims can violate order even when each batch is sorted.
- Make shutdown, cancellation, lease renewal, and restart recovery explicit. Keep network waits outside long database transactions unless a verified implementation justifies another tradeoff.

## 4. Close the consumer and operations contract

For consumer effects in one database, atomically commit deduplication identity and domain changes, then acknowledge. External effects require provider idempotency or reconciliation; a processed-event row alone cannot atomically cover a remote service. Define duplicate/out-of-order/version-gap behavior and dedup retention relative to replay history.

Observe oldest pending age, backlog size/growth, send/ack failures, retry/parked counts, and relay health without leaking payloads. Define retention cleanup that preserves replay obligations, and runbooks for broker outage, stuck leases, poison payloads, and safe replay.

Plan additive schema rollout, indexes, producer enablement, relay enablement, consumer compatibility, and rollback without abandoning pending rows. Use repository migration methodology when available; do the same compatibility reasoning inline otherwise. Do not execute migrations, replay, or production operations merely to validate the design.

Illustrative crash trace: commit order + outbox → broker accepts event → relay crashes → new worker republishes same event ID → consumer dedup suppresses a repeated local effect. The second publication is allowed; losing the committed intent is not.

Counterexample: a transient in-process HUD update needs subscription lifetime handling, not a transactional outbox.

## 5. Verify and report

Use real disposable database integration checks for shared transaction rollback, concurrent claims, stale completion, and ordering constraints; simulate broker failure and crash after acknowledgement. Check duplicate consumer effects, poison events, restart recovery, version compatibility, and backlog query behavior as relevant. Do not infer transaction correctness from mocked call order alone.

Report the atomic write boundary, event/schema and ordering contracts, relay/consumer owners, crash-window table, delivery assumptions, rollout/recovery plan, observability, and checks run or planned. Return broader system decisions to the architecture/planning caller; apply the core quality gate.
