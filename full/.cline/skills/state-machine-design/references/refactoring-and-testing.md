# Refactoring, data processing, and testing

Read for an existing implementation or a processing lifecycle with async work, retries, cancellation, or persistence. Examples are illustrative; preserve the target repository's actual contracts.

## Refactor an implicit lifecycle

1. Map all state writes and effects, including error/reset handlers and callbacks. Trace producers/consumers of status fields and persisted values. Record current observable behavior, including existing event ordering.
2. Extract the observed transition table. Identify contradictory flags, ambiguous priorities, or transitions that bypass checks. Distinguish a representation refactor from any proposed behavior correction; do not silently invent missing product rules.
3. Capture consequential behavior with existing tests or a deterministic reproduction. Include a negative/interruption sequence. Tests should constrain outcomes and resource lifetime, not require the old helper names.
4. Establish one commit path for transitions. Move callers to requests/events incrementally; remove their independent state writes. Preserve public entry points through adapters when needed. Avoid two authoritative models that can drift during migration.
5. Replace redundant flags only after consumers use the new authority or derived compatibility views. Review serialized names, enum ordinals, event payloads, save games, metrics, and external status APIs before changing them.
6. Compare before/after traces and effects for the same inputs. If durable data changes, plan mixed-version reads, migration, restart behavior, and rollback after new writes. Use the repository's migration workflow; a code rollback alone may not restore an old persisted contract.

## Example: processing attempt lifecycle

The processing algorithm can remain ordinary functions. The machine owns whether a job may start, accept results, cancel, or retry.

| Source | Event | Guard | Target | Data/effect contract |
|---|---|---|---|---|
| queued | start | valid request | running | Assign fresh attempt ID; request processing. |
| running | completed(id, result) | ID matches active attempt | succeeded | Store result and release attempt resources. |
| running | failed(id, error) | ID matches active attempt | failed | Record error and release attempt resources. |
| running | timeout(id) | ID matches active attempt | failed | Record timeout; request cancellation/cleanup. |
| queued / running / failed | cancel | cancellation permitted | cancelled | Clear pending retry; request cleanup if running. |
| failed | retry | retry budget remains | running | Assign a new attempt ID; request another attempt. |
| any | completion/failure/timeout for an obsolete attempt | stale ID or incompatible state | unchanged | Discard stale notification; no repeated result commit. |

Here `succeeded` and `cancelled` are terminal for this job; `failed` waits for retry or cancellation. Define all other event outcomes by policy, such as rejecting a new `start` while running and ignoring duplicate completion after success. Multiple overlapping guards require explicit priority; the stale-notification rule is a fallback after eligible active-attempt transitions.

Do not mechanically copy these states into a different domain. If an external operation can commit after cancellation, a terminal `cancelled` label may be misleading. Model pending cancellation/reconciliation when necessary. Aborting a local wait cannot undo a remote commit.

## Streaming parsers

Chunk boundaries are transport details, not record boundaries or end-of-input. A scanner for non-nested quoted records can retain `outside`, `quoted`, and `escaped-in-quote` modes plus an unfinished record buffer across calls. Keep mode separate from buffer data. Decide whether the scanner preserves delimiters/escapes or also decodes them; do not silently change output format during the refactor.

Model end-of-input explicitly: define incomplete quote/escape errors and whether an unterminated final record is emitted or rejected. Compare whole-input decoding with different chunk partitions of the same input, including splits at quotes, escapes, embedded newlines, and empty chunks. For byte chunks, account for characters split across chunks using the existing incremental decoder. Preserve configured record-size/resource limits; a state machine does not itself bound buffer growth.

## Effects, async work, and recovery

- A serialized owner prevents interleaved local transitions only when every mutation uses it. Across workers, enforce the repository's transaction/locking/version checks; an in-memory check does not arbitrate a persistent race.
- Guards should read stable inputs and decide eligibility. Perform I/O at the established effect boundary. Return async outcomes as correlated events so a cancelled or superseded attempt cannot overwrite current state.
- Specify what happens if an effect fails before starting, succeeds but acknowledgement is lost, or the process crashes between an effect and a state write. Persistent state and external effects are not automatically atomic. Use existing idempotency/reconciliation mechanisms where required; add infrastructure only for a demonstrated requirement.
- Identify timer ownership, per-attempt versus overall deadlines, retry limits/backoff, and cleanup on every relevant exit. Indefinite waiting may be intentional; require a timeout or cancellation/recovery policy according to the domain, not an arbitrary timeout for every state.
- Define whether re-entry restarts work. An entry action is not an exactly-once action. De-duplicating notifications in memory is not durable exactly-once execution of external work.
- Persist only if restart/resume is required. Restore the state and valid context together, recognize obsolete schema versions, and explicitly decide whether pending work resumes, restarts, or reconciles. Do not introduce storage for an ephemeral machine.
- Check authorization and untrusted event payloads at the existing trust boundary. A transition being legal does not prove the sender is allowed to request it.
- For operationally significant machines, trace entity/attempt ID, source, event, target, and rejection reason without sensitive payloads. This should explain a failed sequence without logging every frame or every record.

## Meaningful validation

Start with deterministic examples using existing test tools:

- Allowed transitions with guard boundaries, ordered alternatives, unsupported events, and intentional terminal states.
- State/data invariants after each event; important states are reachable; an unintended dead end or immediate transition cycle is exposed.
- Entry, exit, and transition effects occur with the specified order and repetition policy, including same-state events.
- Start → cancel → late completion cannot publish a successful result; retry → old timeout cannot fail the new attempt; duplicate completion cannot repeat the commit.
- Effect startup failure, cleanup, partial failure, restart, and competing workers where those boundaries exist.

Inject clocks, scheduling, and I/O at the existing boundary rather than using arbitrary sleeps. Test observable outputs/resources alongside state labels. A test that merely copies the transition table into another switch can reproduce the same modeling error.

For a large sequence space, use the project's existing model-based/property-based tools to generate event traces and check invariants after each step. Keep the reference model independent enough to catch implementation errors; preserve minimized failing traces as regressions. Exhausting a few example transitions does not establish correctness for all sequences.

[Hypothesis stateful testing](https://hypothesis.readthedocs.io/en/latest/stateful.html) documents action-sequence generation and per-step invariants (consulted 2026-10-19); this is a testing technique, not a requirement to add Python or Hypothesis. [Stately invocation lifecycle](https://stately.ai/docs/invoke) illustrates state-owned async work; verify cancellation semantics in the actual runtime and external API.
