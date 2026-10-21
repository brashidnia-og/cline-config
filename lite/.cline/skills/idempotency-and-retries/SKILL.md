---
name: idempotency-and-retries
description: Design, implement, or review safe retry and duplicate-execution behavior for APIs, jobs, commands, consumers, and external side effects. Use for ambiguous timeouts, idempotency keys, concurrent duplicates, retry storms, deduplication retention, or crash recovery. Establish the effect boundary and budget before adding retries; skip pure local calculations with no retry or delivery problem.
---

# Idempotency and retries

Goal: make repeated attempts converge on the intended effects without confusing a timeout or cancellation with proof of failure.

## 1. Trace the effect and failure boundary

Respect the requested mode. Inspect callers, handlers, client/library retry defaults, persistence/transaction code, external provider contracts, and tests. List each effect, where it commits, and who can retry it (caller, SDK, worker, broker, operator). Do not infer safety from a method name such as `read`, `put`, or `execute` alone.

Distinguish naturally idempotent effects, request deduplication, response replay, and exactly-once processing claims. A local retry loop cannot guarantee exactly-once external effects. Use a direct failure path when the operation cannot safely be repeated or reconciled.

## 2. Define the idempotency contract

- Define the logical operation, caller/tenant scope, key origin, and retention window. A correlation ID is not automatically an idempotency key; the same logical retry must reuse the same key.
- Bind a key to a versioned, deterministic fingerprint of the relevant normalized request. Reject a reused key with different intent; scope lookup and replay so one caller cannot obtain another's response.
- Specify new, in-progress, completed, failed, and unknown outcomes as needed. Define concurrent-duplicate behavior (wait with a bound, return in-progress, or replay); avoid unlocked check-then-act.
- For local database effects, atomically couple the claim/unique constraint, domain mutation, and final durable result where the transaction model permits. A dedup record committed before an unrelated effect can become a permanent false success or stuck claim.
- For external effects, pass the same provider-supported idempotency key or reconcile by durable operation identity. A local database transaction does not include the remote commit. A crash after remote success but before local completion is an unknown outcome, not permission to send a fresh operation.
- Define lease recovery and stale-worker fencing if work can be reclaimed; an expiring lock alone does not stop the old worker. Keep terminal responses and sensitive fields only for the required bounded retention.
- State what happens after key expiry. Deleting a record can permit the effect again; retention must cover delayed delivery, client retries, and provider guarantees. Preserve compatibility of stored fingerprints/results across deploys.

## 3. Give retries a bounded policy

- Classify retryable failures from verified contracts; distinguish transport failures, throttling, permanent validation/auth failures, concurrency conflicts, and ambiguous commits. Retry only replayable inputs and acceptable duplicate-safe effects.
- Choose one policy owner per boundary. Account for SDK and broker retries so nested policies do not multiply attempts and outage load.
- Specify total attempts (including the first), capped backoff with jitter, overall elapsed budget, per-attempt timeout, and server retry hints where supported. Stop when the next wait/attempt cannot fit the actual deadline.
- Distinguish cancellation from a deadline; a signal may provide no remaining-time API. Make backoff waits interruptible, propagate context, and stop new attempts after cancellation.
- Cancellation or timeout may stop waiting while the server still commits. Preserve reconciliation identity instead of falsely recording that nothing happened.
- Bound queued work/concurrency and define overload behavior. Add circuit breaking only when requirements justify a separate outage-control policy, not as a ritual companion to retry.

## 4. Trace crash windows and recovery

Illustrative payment flow: claim `(tenant, key, fingerprint)`, submit with the same provider key, and store/replay the result. If the response is lost, query/reconcile using that identity before deciding whether another submission is safe. Do not mark success on enqueue unless the API explicitly promises only acceptance.

For a consumer whose effects are entirely in one database, commit the processed-event marker and the domain changes together; acknowledge after commit. Use `transactional-outbox` when that commit must also create durable publication intent. Keep retry policy separate from `decorator-pattern`, which only determines wrapper structure/order.

Counterexample: retrying a non-idempotent charge with a new UUID on every attempt defeats deduplication even if the loop has backoff.

## 5. Verify and report

Use meaningful checks for same-key replay, different-payload conflicts, concurrent duplicates, crash before/after each commit boundary, expired claims/keys, stale workers, lost responses, transient versus permanent errors, budget exhaustion, and cancellation as applicable. Use real transaction/constraint integration checks where database atomicity is the claim, deterministic clocks/backoff elsewhere, and disposable/simulated provider boundaries.

Report effect and atomicity boundaries, key/fingerprint/retention contract, outcome/recovery states, retry owner and budget, external guarantees still unknown, and checks run or planned. Reuse existing schema/migration guidance if implementing persisted changes; apply the core quality gate.
