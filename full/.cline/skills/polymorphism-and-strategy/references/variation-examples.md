# Variation examples (illustrative)

Illustrative patterns, not real project APIs. Each states what varies, what was chosen, why, and the resulting contract.

## Data/configuration (same algorithm, different constants)

Five notification channels differ only in endpoint, retry count, and payload template.

- **Chosen:** one `channels` table; the sender algorithm is unchanged.
- **Why:** no branches and no new type per channel; a new channel is a row, not a class.
- **Contract:** the algorithm reads the table as read-only configuration; invalid rows fail at load with a named error.

## Strategy (different algorithms, common contract)

Three ways to obtain connection data (local cache, remote HTTP, embedded index) share `lookup(key) -> result`.

- **Chosen:** one interface plus three implementations; selection at construction; cache-then-remote is an ordered pair of strategies, not a fourth hybrid class.
- **Why:** each implementation is testable in isolation; the fallback order is stated once, at the dispatch boundary.
- **Contract:** `lookup` timeout/cancellation semantics are shared; per-implementation errors are typed and surfaced, not converted into a common sentinel that hides the cause.
- **Evaluation:** assert the same success/miss semantics for cache, HTTP, and embedded implementations; also test a distinct HTTP timeout or malformed response so the transport-specific failure remains visible.

## Composition (independent capabilities)

A chat client can independently vary transport, presence handling, and history storage.

- **Chosen:** three independent parts composed in the client; no `ChatClientBase` that specializes all three axes.
- **Why:** an inheritance hierarchy creates combinations of combinations (N×M×K classes).
- **Contract:** each part has its own lifecycle owner; the client owns the order of setup and teardown.

## Explicit state model (lifecycle variation)

A session progresses through connecting → active → reconnecting → closed, and the allowed transitions differ per transport.

- **Chosen:** one state enum with a single owner (the session object); transitions are explicit functions; per-transport differences show up only as which transitions are allowed.
- **Why:** a strategy over “connection behavior” would leave shared mutable state (retry counters, in-flight messages) without a clear owner.
- **Contract:** the state enum is closed; every state has one entry path; tests cover all allowed transitions plus one illegal transition per state.

## Factory/registry (construction selection)

Callers repeatedly wrote `if kind == "a" … elif kind == "b" …` to pick an implementation.

- **Chosen:** a registry mapping kind → constructor at the composition boundary; callers request an instance, not selection logic.
- **Why:** the policy was duplicated across six call sites and had drifted.
- **Counter-check:** if selection happens in exactly one place, keep it inline — a registry there is ceremony, not design.

## Exhaustive match (closed set)

See `design-for-change`'s examples: for a closed enum and small transformations, exhaustive match beats one-implementation-per-state, because the language forces every case to be handled at each use site.

## The sixth-variant exercise

After choosing, answer once, in writing:

1. What is the sixth option you did not pick (a plain conditional, one class with data, one more level of indirection, an existing framework feature, no abstraction, a full hierarchy)?
2. Why is it not viable *here* — in this repository, with these callers and tests?
3. What would have to be true for the sixth option to become correct?

If the answer to 2 is “it looks uglier,” that is not a justification — re-evaluate. The exercise runs in both directions: it catches over-abstraction and rescues under-abstraction.
