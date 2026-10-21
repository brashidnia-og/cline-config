---
name: adapter-pattern
description: Design, implement, or review adapters between incompatible contracts, including third-party APIs, legacy services, storage systems, and provider integrations. Use when translating external types, errors, units, capabilities, pagination, or versions into a project-owned contract. Skip compatible pass-through calls and algorithm selection alone; those may need a direct call or strategy instead.
---

# Adapter pattern

Goal: isolate an actual contract mismatch at a boundary without pretending incompatible capabilities are equivalent.

## 1. Inspect and establish fit

Honor the requested explain/plan/review/implementation mode. Inspect callers, external client/version, DTOs, existing integrations, and tests. Name the caller's required contract and the supplied contract separately; do not invent SDK methods or hide missing facts behind casts.

- Use an adapter for translation; use `polymorphism-and-strategy` for selecting interchangeable behavior and `decorator-pattern` for adding behavior around an already compatible contract.
- Prefer an existing boundary mapper or a direct function when that owns the entire mismatch. Do not add port/interface/repository layers simply to label the pattern.
- If a provider lacks a required capability, expose a narrower capability or an explicit unsupported outcome. Do not fabricate successful results, silently approximate, or fill required data with defaults.

## 2. Define the mapping contract

Record a compact source → target mapping for relevant fields and outcomes:
- Identity, tenant/ownership context, enum/unknown values, null versus absent, and required fields.
- Currency/units, precision/rounding, timestamp/time zone, inclusive/exclusive ranges, and ordering.
- Pagination/cursors, streaming/laziness, partial results, duplicate records, and consistency/freshness.
- Not-found, invalid input, authentication, authorization, rate limits, transient failures, and cancellation. Preserve diagnostic causes internally without exposing provider secrets or raw sensitive responses.

Use project-owned types at the boundary where useful. Keep provider DTOs and SDK exceptions out of unrelated business logic, but do not erase information needed for recovery. Identify lossy conversions and reject them or make the loss explicit.

## 3. Place ownership and side effects

- Inject the supplied client explicitly and compose at the existing construction boundary. State whether the adapter borrows or owns it and who closes connections/streams.
- Validate untrusted responses at runtime; static types do not establish payload validity. Bound page sizes, pagination work, response size, and concurrent requests.
- Forward cancellation/context deliberately. Do not turn a lazy stream into an unbounded in-memory list to simplify mapping.
- Keep authorization and tenant identity intact across translation. Validate destinations and redact credentials according to the existing network boundary.
- Do not introduce hidden retries for writes. Use `idempotency-and-retries` if retry semantics are unresolved; keep one retry owner.
- If SDK/schema versions change, inspect producers and consumers, unknown-field behavior, mixed versions, and rollback. Use verified version-specific documentation for external facts.

## 4. Implement the smallest translation

Separate pure field/error mapping from I/O when it improves clarity. Keep supported capabilities explicit; avoid universal provider interfaces with methods most implementations cannot honor. Preserve valid domain invariants even when the external system is more permissive.

Illustrative example, not a project API: a supplier returns an integer price in cents and an optional timestamp string. Map cents into the project's verified money representation without floating-point loss; parse time according to the supplier's documented zone; distinguish absent time from malformed time. Do not assume every supplier uses cents, UTC, or the same not-found response.

Counterexample: selecting among three already compatible compression functions is strategy selection, not an adapter problem.

## 5. Verify and hand off

Use repository-established checks: representative and malformed payloads, unknown enum/fields, precision and time boundaries, error translation, pagination termination, cancellation, and cleanup as applicable. Use sanitized fixtures at the external boundary, not live credentials or broad network calls. Verify at least one real caller path so passing mapper tests do not conceal incorrect wiring.

Report the mismatch and evidence, supported capabilities, mapping/loss policy, state/resource owners, integration point, compatibility concerns, and actual validation results or planned checks. Return the boundary decision to `design-for-change` when it is the caller; apply the core quality gate.
