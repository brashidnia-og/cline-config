# Code style and architecture policy

Architecture is a means to preserve invariants, ownership, testability, and change boundaries—not a checklist of named patterns.

## Existing architecture first
Before creating a new abstraction:
1. Inspect how the repository currently solves adjacent problems.
2. Identify the invariant or volatility the abstraction would own.
3. Confirm an existing component cannot cleanly own the behavior.
4. Prefer the smallest design consistent with repository conventions.

Do not introduce a layer solely to satisfy CLEAN/SOLID terminology. Do not create pass-through abstractions that add indirection without ownership, aggregation, policy, isolation, or independent test value.

## Ownership and boundaries
Prefer clear answers to:
- What invariant must remain true?
- Who owns each piece of state (source of truth)?
- Where do side effects occur (I/O, persistence, events, network)?
- What is the trust boundary for untrusted input?
- How are failures, retries, and partial success handled?

Use the repository’s existing names and layers. Do not force foreign role names (e.g. UseCase/Outbox/Repository) into codebases that use different established concepts. Introduce patterns such as transactional outbox only when atomicity between local persistence and eventual publication is a real requirement.

## Design quality
Prefer:
- cohesive components with explicit dependencies,
- clear state ownership and source of truth,
- typed domain boundaries,
- explicit side effects,
- pure logic where it improves reasoning/testing,
- dependency direction that avoids cycles,
- composition over inheritance when practical,
- idempotent operations where retries/duplicates are expected.

Avoid:
- generic god/service classes,
- hidden global state,
- temporal coupling without an explicit protocol,
- speculative extension points,
- duplicated business rules across layers,
- leaking persistence/network DTOs deep into domain logic without reason,
- abstractions created only to make mocking easier.

## Cross-cutting architecture gate
For cross-component changes identify as applicable:
- domain invariants,
- entry points/data flow,
- state ownership/system of record,
- transaction/consistency boundaries,
- failure/retry/idempotency behavior,
- trust/auth boundaries,
- public/persisted contracts,
- performance/scaling implications,
- observability,
- deployment/migration/rollback.

For substantial architecture planning, activate the `architecture-review` skill rather than expanding this always-on rule into a full design playbook.
For substantial UI/React/Redux work, activate the `frontend-engineering` skill.
