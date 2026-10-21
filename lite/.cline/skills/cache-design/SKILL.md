---
name: cache-design
description: Design, implement, or review cache correctness and lifecycle for local or distributed caches. Use for key/tenant isolation, freshness and invalidation, stale repopulation, cache stampedes, negative caching, memory bounds, or outage behavior. Require an explicit source of truth and staleness contract; skip cheap pure calculations and speculative caching without an observed need.
---

# Cache design

Goal: reduce repeated work while preserving an explicit freshness, isolation, and resource-use contract.

## 1. Inspect the need and source of truth

Respect the requested mode. Inspect reads, writes, query dimensions, existing caches/framework features, data ownership, measured cost, and tests. Identify the authoritative store and required consistency; do not use caching to conceal an unbounded query or an unknown bottleneck.

Compare no cache, query/index improvement, per-request memoization, bounded in-process cache, shared cache, and framework/server-cache facilities. Choose from actual access patterns and deployment topology; more layers create more invalidation and outage states.

## 2. Define identity and freshness

- List every result-affecting dimension: tenant, principal/permission scope, resource/query/filter, locale, representation/schema version, and relevant feature/config version. Define deterministic normalization and avoid ambiguous key concatenation.
- Authorize access on every required path, including hits. A scoped key alone does not enforce current permissions; authorization outside the cache alone does not fix incorrect key identity. Use `decorator-pattern` only for structural wrapper order.
- Distinguish a miss from a cached null/empty/negative result and from a cache failure. State which errors or not-found outcomes may be cached, for how long, and under what identity.
- State acceptable staleness, TTL and its clock semantics, refresh policy, maximum stale age, invalidation owner, and consistency after writes. TTL bounds staleness only under the actual fill/refresh protocol; it is not a proof of immediate correctness.
- Specify serialization/version compatibility, rolling deploy behavior, sensitive-data retention, and whether values are immutable/copies or caller-mutable shared objects.

## 3. Choose write/fill/invalidation behavior

- Show cache-aside, read-through, write-through, or another verified flow, including write failure, cache failure, transaction rollback, and process crash. Avoid acknowledging a durable write merely because a cache entry changed.
- Trace the stale-fill race: reader starts old load → writer commits and invalidates → old reader repopulates. Choose version checks, generation fencing, ordering, or another mechanism consistent with the required freshness; deletion alone does not eliminate this race.
- Define which writes invalidate which keys/derived collections and how multiple application instances receive that invalidation. Keep one source of truth for the policy.
- For stampede control, coalesce loads by correctly scoped key and bound waiting/concurrency. Clear in-flight entries on error/cancellation. One waiter's cancellation must not unintentionally cancel a shared load still needed by others.
- If distributed locking is used, define expiry, ownership/fencing, failure recovery, and stale writers. A lock is not automatically a correctness guarantee.
- For invalidation via events, define lost/duplicate/out-of-order event behavior and a bounded-staleness fallback. Use `transactional-outbox` only when committed writes require durable invalidation intent.

## 4. Bound resources and outages

- Bound entries/bytes, key/value sizes, in-flight fills, loader concurrency, and queues. Set eviction/admission policy from workload; TTL without eviction/cleanup does not necessarily bound memory.
- Define cache-unavailable behavior: bypass, fail, or serve explicitly permitted stale data. Protect the authoritative store from a cache outage becoming an unlimited load surge.
- Bound background refresh and retry work; jitter refresh/expiry when justified by synchronized load. Use `idempotency-and-retries` for unresolved retry policy rather than nesting hidden loops.
- Observe hit/miss/negative-hit rates, loader latency/errors, eviction, oldest stale age, fill contention, memory, and fallback load. Keep keys/principals out of sensitive logs and high-cardinality labels.

Illustrative tenant-scoped profile cache: key includes verified tenant and relevant permission/representation version; access is checked before a hit is returned. A version-fenced fill prevents an older load overwriting a newer committed generation. The exact mechanism depends on the store; do not invent atomic APIs.

Counterexample: a cheap pure formatter called once per request may need no cache. A best-effort cached status must not become the authority for an irreversible authorization or balance decision.

## 5. Verify and report

Use deterministic clocks and coordinated concurrency for scoped-key collisions, miss/null/failure distinctions, expiry/refresh, stale fill after invalidation, concurrent misses, waiter cancellation, mutable-value leakage, memory bounds, and outage fallback as relevant. Verify write/rollback and multi-instance invalidation with the actual integration boundary when those semantics matter. Compare performance only with a representative baseline.

Report source of truth, measured need, key and freshness contract, write/fill/invalidation owner, concurrency/outage/resource limits, compatibility, observability, and checks run or planned. Return the cache policy to the caller without redesigning unrelated storage; apply the core quality gate.
