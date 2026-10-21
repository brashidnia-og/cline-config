---
name: command-pattern
description: Design, implement, or review commands that represent intent separately from execution for queued work, editor actions, gameplay input, undo/redo, or delayed operations. Use when commands need validation, handlers, history, serialization, cancellation, or duplicate-execution semantics. Skip ordinary immediate calls with no scheduling/history need; Command does not imply CQRS, event sourcing, or a message broker.
---

# Command pattern

Goal: represent an operation's intent explicitly when its execution, scheduling, or history needs independent ownership.

## 1. Inspect and choose the lightest form

Respect the requested mode. Inspect the invoker, receiver/handler, state owner, execution boundary, and existing queue/history/input systems. A direct method call stays direct when nothing needs to be deferred, recorded, replayed, or undone.

- An in-memory callable or small typed value plus a handler may suffice. Do not require a class per operation or a command bus for a single call.
- A command requests an action; an event describes a fact that already occurred. Use `observer-and-events` for notification design, not to disguise commands as broadcasts.
- Command alone does not require CQRS, event sourcing, durable storage, or distribution. Identify which of these is actually needed before designing their contracts.

## 2. Define intent and execution semantics

- Name the operation, target identity, parameters, caller/tenant context, result, and allowed failures. Prefer immutable intent; avoid capturing mutable UI objects or live service references in persisted commands.
- Distinguish validation at creation/enqueue time from authorization and invariant checks at execution time. State may change while queued; re-check current authority or explicitly define a bounded delegated capability.
- Define ordering, preconditions/version checks, expiry, priority, cancellation, and whether concurrent commands on the same target are legal. A queued command is not guaranteed to execute against the original state.
- Separate the command ID/correlation ID from any idempotency key. Use `idempotency-and-retries` for durable duplicate execution and unknown outcomes.
- For persisted commands, specify schema/version compatibility, supported old payloads, unknown commands, sensitive data retention, and safe deserialization. Do not serialize arbitrary executable objects or trust client-supplied actor IDs.

## 3. Place effects and lifecycle ownership

The handler/receiver owns domain changes; the invoker owns submission; the scheduler owns bounded queueing and delivery; the history owner owns accepted undo/redo records. Use the repository's existing names. Define transaction boundaries, acknowledgement timing, failure reporting, shutdown, and recovery if execution crosses processes.

Cancellation before execution can remove or reject pending intent; cancellation after effects begin does not necessarily roll them back. For timed gameplay input, state the frame/tick and stale-input policy. Keep per-execution state out of reusable command definitions.

## 4. Treat undo as a separate contract

- Decide whether an operation is truly reversible, compensatable, or irreversible. Sending an email or charging an external provider cannot be generically undone by reversing local fields.
- Record the prior state or inverse data needed for a successful edit, scoped to its target/version. Reject or resolve conflicts if someone changed that state before undo.
- Append to undo history only after the defined success boundary. Define redo after undo, what a new edit does to the redo branch, and behavior on failed execution/undo.
- Bound history size; specify grouping/coalescing and ownership of retained resources. Do not replay external effects just to rebuild UI history.

Illustrative editor flow: `MoveNode(nodeId, targetPosition, expectedVersion)` executes through the document owner; on success, history records the old position and resulting version. Undo applies only under the chosen conflict rule. A durable payment command instead needs deduplication/reconciliation and possibly a compensating refund, not a generic inverse method.

Counterexample: a private calculation executed immediately once needs no command object or registry.

## 5. Verify and hand off

Use meaningful checks for execution-time authorization/preconditions, successful effects, failed commands leaving no false history, undo/redo branching and conflicts, duplicate delivery, expiry/cancellation, and serialization compatibility as applicable. Use deterministic clocks/schedulers for queued or gameplay behavior.

Report why intent needs separation, payload/result contract, handler/state/queue/history owners, ordering and failure semantics, persistence/undo limits, and checks run or planned. Return the command decision to `design-for-change` when it is the caller; apply the core quality gate.
