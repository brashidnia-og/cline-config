# Factory, Builder, and composition root

These are illustrative design choices, not project APIs. Inspect the repository's existing constructors, DI container/version, startup/shutdown flow, and tests before changing them.

## Pick the responsibility before the pattern

| Situation | Smallest candidate |
|---|---|
| One known implementation and valid inputs already available | Direct constructor or function |
| Named optional values with simple validation | Existing options/value object or language named/default arguments |
| Runtime selection or repeated creation with a real policy | Small factory function/object at that boundary |
| Families of compatible products that genuinely vary together | Evaluate an abstract factory; do not create one for a single product |
| Staged configuration, dependent options, or invalid intermediate states | Builder with an explicit validated build boundary |
| Application startup wires concrete dependencies and scopes | Existing composition root/bootstrap or native DI container |

A factory owns creation/selection, a builder owns accumulation/validation of construction inputs, and a composition root owns the application dependency graph and lifetimes. They need not all exist. Do not confuse Factory Method (overridable creation through inheritance) with every factory function; prefer composition unless existing extension requirements justify inheritance.

Keep those construction choices here. For focused analysis of injection boundaries, captive dependencies, scope isolation, cycles, or container behavior, use [dependency-injection](../../dependency-injection/SKILL.md), then return the resolved graph/lifetime constraints to this construction owner. DI, IoC, DIP, and containers do not require separate competing wiring designs.

## Define the construction contract

- Required inputs, safe defaults, validation order, unsupported variants, and useful failure results. Do not defer a known invalid configuration until an unrelated runtime method fails.
- Scope: shared/singleton, per request/session, per operation, pooled, or transient. A shared instance is a lifetime choice, not a reason to add a globally accessible Singleton.
- Configuration is not a service locator. Inject needed dependencies explicitly; avoid constructors that reach into a global container or silently open connections on import.
- Builders should not leak mutable partially built products. Define whether build consumes or snapshots state, whether builders can be reused, and whether repeated build shares resources. Use staged types only when they prevent important invalid states without excessive ceremony.
- Factories should expose the minimum product contract while preserving real capability differences. Keep runtime provider selection out of business call sites; use `adapter-pattern` for translation and `polymorphism-and-strategy` for interchangeable behavior.
- Compose decorators/pipeline stages explicitly once; avoid self-resolution cycles and accidental double wrapping. Validate missing registrations at the appropriate startup boundary.
- Name who owns versus borrows each resource and who disposes it. Roll back resources already acquired if later construction fails; do not close borrowed clients. Normal shutdown should follow dependency requirements, commonly reverse acquisition order, and be idempotent where repeated cleanup is possible.
- Define async startup, cancellation, and failure visibility. Avoid publishing an incompletely initialized object or holding application locks while awaiting external initialization without a verified reason.

## Worked decisions

**Factory fits:** two storage providers are selected from validated application config. Bootstrap invokes one small factory, injecting the relevant clients; business services receive the project contract. Unsupported config fails visibly. The factory does not rediscover the provider on every method call or conceal network retries.

**Builder may fit:** an export job requires a destination plus format-specific options, with some combinations forbidden. A builder gathers inputs and validates the complete combination before exposing an immutable job definition. An ordinary typed options object remains preferable if it establishes the same invariants more clearly.

**Composition root fits:** bootstrap owns a transport client, creates an adapter borrowing it, and wraps the adapter with metrics. If wrapper initialization fails, bootstrap closes resources it owns; it leaves injected borrowed clients alone. On shutdown, dependents stop before the transport closes.

**Decline extra structure:** a private pure helper with two arguments needs no factory interface, builder, container, or Singleton.

## Verification and handoff

Choose checks for valid/invalid configuration, product selection, builder snapshot/reuse behavior, scope isolation, dependency cycles, partial acquisition failure, cancellation, and exactly the intended resource cleanup. Verify real application wiring with existing startup/integration checks where practical; do not merely assert that a mocked factory was called.

Return the chosen creation/wiring mechanism, validation boundary, scopes and ownership, failure/cleanup behavior, and checks run or planned to `design-for-change`. Keep the canonical design owner there and apply the core quality gate.
