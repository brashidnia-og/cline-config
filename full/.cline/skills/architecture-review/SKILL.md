---
name: architecture-review
description: Design or critically review software/system architecture and implementation plans. Use for system design, architecture decisions, major refactors, new components/services, distributed workflows, API/event design, performance/scaling design, or when the user asks for a deep implementation plan before coding. Skip for trivial typos/renames/one-line copy fixes.
---

# Architecture review and planning

Goal: produce an implementation-ready design grounded in the actual repository and requirements, not generic pattern matching.

## 1. Define the design problem

Establish:
- objective and observable acceptance criteria,
- non-goals,
- current architecture/flow,
- functional and non-functional constraints,
- compatibility and deployment constraints,
- material unknowns.

Inspect relevant code/config/tests/dependencies before proposing repository-specific architecture.

## 2. Identify invariants and ownership

State the invariants that must always remain true.
For each important piece of state identify:
- owner/source of truth,
- readers/writers,
- lifecycle,
- consistency requirement,
- trust boundary.

Trace the end-to-end control/data flow from entry point to durable/external effects.

## 3. Failure and consistency model

Define as applicable:
- transaction boundaries,
- atomic vs eventual guarantees,
- retries/timeouts/backoff,
- idempotency/duplicate delivery,
- partial failure/crash recovery,
- concurrency/ordering,
- cache invalidation/staleness,
- external dependency failure behavior.

Do not label a system “exactly once”, “atomic”, or “idempotent” without specifying the boundary and mechanism.

## 4. Contracts and evolution

Inventory affected:
- public APIs,
- DB schemas/indexes/constraints,
- event/message formats,
- cache/persisted serialization,
- config/env/CLI contracts,
- client/server boundaries.

Plan mixed-version compatibility. Prefer additive evolution and expand/migrate/contract when needed. Consider rollback after new data/events have been emitted.

## 5. Security and privacy

Identify trust boundaries, authn/authz, ownership/tenant controls, sensitive fields/logs, untrusted inputs, outbound requests, secret handling, and abuse/resource exhaustion relevant to the design.

## 6. Performance and operations

Estimate bottlenecks from the real workload where possible:
- latency/throughput,
- CPU/memory/network/storage,
- query/index behavior,
- fan-out/batching,
- queue/backpressure,
- horizontal/vertical scaling limits.

Use remote-math for non-trivial capacity/precision calculations when useful.

Define observability:
- logs with useful identifiers but no secrets,
- metrics/invariants/SLO signals,
- traces where cross-boundary diagnosis matters,
- alerts and operational failure modes.

## 7. Compare alternatives

For consequential decisions compare at least two viable options unless one is clearly forced by existing architecture/requirements.

Evaluate:
- correctness/invariants,
- complexity,
- operational burden,
- performance,
- compatibility/migration,
- testability,
- reversibility,
- fit with existing code.

Do not choose the most sophisticated or familiar pattern by default. Select the simplest design that satisfies verified requirements.

## 8. MCP use

- Context7: verify external library/framework capabilities at the installed/target version.
- Tavily: verify current official support matrices, release notes, advisories, or standards when freshness matters.
- Browser MCPs: only when architecture depends on actual browser/runtime behavior.
- remote-math: capacity, precision, rates, sizing.

External tools resolve external facts; they do not dictate repository architecture.

## 9. Implementation plan

Produce an ordered plan that surfaces risk early. For each phase identify:
- files/components/contracts affected,
- intended behavior/invariant,
- implementation steps,
- tests/validation,
- migration/deployment/rollback considerations.

Avoid vague steps such as “update backend” or “add tests”. Make each step executable by another engineer.

## 10. Final gate

Apply the universal quality gate and additional plan gate from `00-core-global`. Premortem for hidden dependencies, partial failure, concurrency/rollback, mixed versions, missed trust boundaries, and unnecessary abstractions. Label assumptions and unresolved decisions.
