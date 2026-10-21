---
name: decorator-pattern
description: Assess, implement, or review the Decorator design pattern — composable wrappers that preserve a component's caller-facing contract while adding behavior. Use for explicit Decorator-pattern requests, optional logging/metrics/cache/retry/authorization wrappers, subclass-combination growth, or bugs caused by wrapper ordering and delegation. Distinguish structural decoration from Python @decorators, TypeScript annotations, and framework middleware; skip this skill for syntax-only annotation questions or trivial forwarding.
---

# Decorator pattern

Goal: add independently composable behavior around an existing component while keeping its caller-facing contract usable. Choose Decorator because wrapping owns a real policy, not because every concern deserves a class.

## 1. Inspect and establish fit

Respect the requested mode: explain, plan, review, or implement. Inspect the existing interface, implementations, callers, construction/DI wiring, and nearby tests before proposing repository changes. For a conceptual question, use a clearly labeled illustrative example rather than inventing project APIs.

Identify the base behavior, the optional additions, and which combinations are actually needed. Compare:

| Need | Candidate |
|---|---|
| Add behavior around the same contract, with independently selectable layers | Decorator: an object wrapper or higher-order function |
| Replace an algorithm or implementation | Strategy; use `polymorphism-and-strategy` if the choice is unresolved |
| Translate an incompatible API | Adapter |
| Control access, remote location, or lazy instantiation | Proxy; structural overlap is normal, so prioritize the actual contract |
| Process a sequence of stages or framework requests | Existing pipeline/middleware/interceptor mechanism |
| One fixed concern with no useful independent composition | A direct helper or existing component |

Distinguish a structural Decorator from language decorator/annotation syntax. A Python function decorator can implement the pattern, but `@` syntax alone does not establish that it does; `@dataclass` transforms a class definition rather than establishing an inner-component delegation chain. TypeScript annotations and framework annotations need their own runtime/version evidence.

When called by `design-for-change`, resolve only the wrapping decision and return the contract and composition order to that caller. Do not restart broader architecture selection.

## 2. Define the preserved contract

Name the minimum interface callers depend on and the behavior each layer adds. Preserve applicable method signatures, return types, error semantics, async/streaming behavior, cancellation, and resource lifecycle. Match the repository's types and protocols; do not introduce a new universal interface or abstract decorator base just for the pattern.

Make intentional deviations explicit: a cache can skip execution and return older data; retry can invoke the inner operation repeatedly; authorization can reject an otherwise valid call. A wrapper with incompatible semantics is not substitutable merely because its types match. Narrow the supported contract or choose a different boundary when needed.

State these ownership rules:
- Which state is per call, per wrapper instance, or shared; who owns cache invalidation and synchronization.
- Whether the wrapper owns or borrows the inner component; who closes/disposes it, and how partial construction fails.
- Whether calls are concurrent or reentrant; keep per-call state out of shared mutable wrapper fields.
- Which entry points require the policy; self-calls on the inner object generally bypass outer wrappers. Returning the raw component or wiring an undecorated path can also bypass policy.

## 3. Write the composition before the code

Show one explicit outer-to-inner expression, for example `Metrics(Retry(Client))`. Trace request flow inward, then result/error/cleanup flow outward. For async or lazy streams, identify when work actually starts, when it completes, and what happens on early termination.

For every order-sensitive pair, state the intended observable difference:
- `Metrics(Retry(Client))` measures a logical call including retries; `Retry(Metrics(Client))` measures each attempt. Decide what counts as success/failure and whether instrumentation failures affect the call.
- Authorization outside a cache checks access even on a hit. Cache identity must still include the relevant tenant/principal and permission scope; ordering alone does not prevent cross-user disclosure or stale permissions.
- A timeout outside retry usually bounds the logical call; one inside retry usually bounds each attempt. Verify the framework's cancellation semantics and carry any overall deadline through the chain.
- Distinguish a cancellation signal from an actual deadline. A signal need not have a timeout or expose remaining time; establish who supplies the budget and clock rather than inventing those capabilities from its type.
- Retry is permitted only when repeated effects are acceptable or enforced idempotent. Bound attempts/backoff, retry only eligible failures, propagate cancellation, and establish whether inputs or streams can be replayed.
- Cache/retry ordering determines what is cached and which work repeats. Decide treatment of failures, concurrent misses, invalidation, and freshness from actual requirements.

Compose once at the existing construction/DI boundary. Ensure the dependency graph terminates at a concrete base, avoid accidental self-resolution/cycles or double decoration, and verify intended callers receive the decorated component. Keep ordering visible rather than inferred from filenames or incidental registration order.

## 4. Implement the smallest coherent wrapper

- Accept the inner component explicitly; delegate through the common contract. Use classes, functions, or native delegation according to existing conventions.
- For each operation, specify whether delegation is exactly once, zero times on a cache hit/rejection, or bounded multiple times for retry. Forward arguments, context, return values, and errors without accidental mutation or loss.
- Add only the owned concern; keep transport/domain policy in its existing owner. Avoid inheritance combinations and flag-heavy all-purpose wrappers.
- Preserve exception causes and cancellation. Run cleanup on failure and cancellation; do not mask the primary failure accidentally with logging or cleanup errors.
- Await the actual operation when measuring async work; wrap iteration when measuring streams. Preserve backpressure, laziness, and early-close behavior rather than buffering an entire stream to simplify instrumentation.
- Do not log secrets or raw sensitive payloads. Define bounded metric labels and the intended behavior when an optional observability sink fails.

For Python callable wrappers, preserve useful metadata with `functools.wraps` and handle sync, coroutine, and generator protocols deliberately. Use repository-supported typing for signatures. For other languages, check native delegation/decorator behavior and avoid assuming that every method is automatically forwarded.

Worked choices and a small illustrative wrapper: [references/composition-examples.md](references/composition-examples.md).

## 5. Verify the observable behavior

Use the project's existing validation tools. Select meaningful checks for the risk rather than testing every forwarding line:
- Base and wrapped components satisfy the relevant shared caller contract; successful values, arguments, and failure/cancellation behavior survive delegation.
- The owned behavior occurs at the intended frequency, including cache hits, rejected calls, exhausted retries, and instrumentation failure where applicable.
- Order-sensitive compositions have deliberate outcomes: one logical metric versus per-attempt metrics, authorization on cache hits, overall versus per-attempt deadlines.
- Construction/DI routes the intended callers through the chain; security checks cannot be bypassed by alternate wiring or inner self-calls.
- Stateful/resource-owning wrappers behave under concurrency, repeated use, partial failure, and cleanup as applicable. For streams, include early termination.

Use deterministic fakes or existing integration fixtures at expensive boundaries. Do not add dependencies or rewrite unrelated components to demonstrate the pattern.

## Result / handoff

Report concisely:
1. **Decision and evidence:** why wrapping fits, or the simpler alternative selected.
2. **Contract and ownership:** preserved behavior, intentional changes, and state/resource owners.
3. **Composition:** outer-to-inner order, construction point, and order-sensitive effects.
4. **Validation:** meaningful checks run/results, or planned checks in plan mode, plus unresolved facts.

Apply the core universal quality gate; keep implementation and canonical design ownership with the caller.
