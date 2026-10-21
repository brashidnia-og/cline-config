# Composition examples

These examples are illustrative, not project APIs. Adapt the language and interface to inspected code.

## A small async wrapper

TypeScript illustration: `Reader<T>` has one operation. The wrapper borrows the inner reader and adds timing. It owns no transport resources or per-call shared state.

```ts
interface Reader<T> {
  read(key: string, signal?: AbortSignal): Promise<T>;
}

class TimedReader<T> implements Reader<T> {
  constructor(
    private readonly inner: Reader<T>,
    private readonly now: () => number,
    // Non-throwing, bounded-label sink; duration uses the clock's units.
    private readonly record: (duration: number) => void,
  ) {}

  async read(key: string, signal?: AbortSignal): Promise<T> {
    const start = this.now();
    try {
      return await this.inner.read(key, signal);
    } finally {
      this.record(this.now() - start);
    }
  }
}
```

The injected clock must also be non-throwing and monotonic. `await` keeps timing around completion, including rejection; omitting it would record before the inner promise settles. Cancellation is forwarded to the inner operation and measured when it settles, not independently implemented. If the supplied recorder can throw, define and implement an instrumentation-failure policy; a throwing `finally` would replace a successful result or mask the primary failure. This example relies on the stated collaborator contracts rather than silently swallowing arbitrary errors.

Meaningful checks: one record after a deferred promise settles; the same value or rejection reaches the caller; the supplied signal reaches the inner reader; concurrent calls keep separate start times. A streaming interface needs a different wrapper around consumption and early close.

## Order is observable behavior

For an idempotent, replayable operation that fails once and then succeeds:

```text
Metrics(Retry(Client))
  one logical metric, two Client attempts, elapsed time includes backoff

Retry(Metrics(Client))
  two attempt metrics: one failure, one success
```

Neither order is universally correct. Pick the one matching the requested measurement; combine distinct logical-call and attempt metrics only when both are needed. Never retry a charge or other non-idempotent side effect merely because it fits the interface.

For access-controlled reads, `Authorize(Cache(Reader))` checks current access on hits. Scope the key and cached data to the relevant tenant/principal/permission context, with an explicit freshness policy. `Cache(Authorize(Reader))` can bypass authorization on a hit. Even the first order fails if another caller can reach the raw cache or if the authorization contract does not cover the cached resource.

## Decline the pattern when it adds no ownership

- Three pricing algorithms are replacement behavior: select a strategy, not a chain that runs all three.
- A fixed formatting step in one private function can stay a helper; do not create an interface, registry, and abstract wrapper hierarchy for hypothetical options.
- A framework already provides ordered request interceptors: inspect and reuse that mechanism before creating a parallel chain with different lifecycle semantics.
- A Python `@dataclass` question concerns language/library behavior, not automatically this structural pattern. A higher-order callable that wraps a service operation can implement Decorator without any class hierarchy.
