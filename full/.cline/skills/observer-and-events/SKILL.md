---
name: observer-and-events
description: Design, implement, or review Observer subscriptions and event notifications in UI, gameplay, and services. Use for subscription leaks, event ordering/reentrancy, listener failures, slow consumers, event payload contracts, or choosing local callbacks versus durable messaging. Distinguish notifications from commands and do not introduce an event bus where direct calls are clearer.
---

# Observer and events

Goal: notify interested consumers while keeping lifecycle, ordering, and delivery guarantees explicit.

## 1. Inspect the notification boundary

Respect the requested mode. Inspect publishers, subscribers, source-of-truth state, event APIs, execution threads/tasks, teardown hooks, and tests. Identify whether the event stays in one process or crosses persistence/network boundaries.

- Prefer a direct call for a required single collaborator, derived state for a computable value, and existing framework subscriptions when they fit.
- Use Observer for interested listeners reacting to a fact. Use `command-pattern` for requesting one owner to act. Do not hide mandatory business sequencing behind unspecified listener order.
- Local callbacks, an in-memory event bus, and a durable broker have different guarantees. Never claim durable delivery because a local publish method returned successfully.

## 2. Define the event and subscription contract

- Name the fact and its owner; specify when it becomes true relative to mutation and transaction commit. Avoid publishing a success event for a transaction that may roll back.
- Prefer immutable snapshots or stable identities plus versions. State whether a listener reads event-time data or current data; deferred listeners must not accidentally observe a reused mutable object.
- Define synchronous versus asynchronous dispatch, listener order or lack of order, thread affinity, nested publish/reentrancy, and whether subscriptions added/removed during dispatch affect that dispatch.
- Specify initial snapshot/replay behavior and how subscription avoids a race between reading current state and listening for changes. Late listeners may need a versioned snapshot rather than replay of transient UI events.
- Define unsubscribe/close semantics, duplicate registrations, once-only listeners, and whether in-flight delivery may complete after unsubscribe. Assign lifecycle ownership to a component/session/scope, not an immortal global registry.

## 3. Own delivery, failures, and resources

- Pair registration with deterministic teardown; weak references do not substitute for an explicit lifetime protocol. Ensure reconnect/remount/re-enable does not accumulate handlers.
- Decide whether one listener's exception stops dispatch, is isolated/reported, or fails the publisher. Await asynchronous listeners or supervise their tasks; do not silently drop rejections.
- Keep dispatch outside locks where feasible. Analyze callbacks that mutate the publisher, unsubscribe themselves, or publish again; use the framework's documented iteration model or an explicit snapshot/queue.
- For asynchronous delivery, bound queues and concurrency; define slow-listener behavior (backpressure, disconnect, drop, coalesce) according to whether intermediate events can be lost. Never drop required business facts as though they were replaceable rendering updates.
- Preserve tenant boundaries and authorization for subscriptions and payloads. Minimize sensitive data and high-cardinality observability.
- For durable delivery, define event IDs, schema/version evolution, ordering scope, acknowledgements, retries, duplicates, and replay retention. Use `transactional-outbox` only when database state and eventual publication must commit together; use `idempotency-and-retries` for consumer effects. At-least-once delivery requires duplicate-safe consumers.

## 4. Trace a useful example and a refusal

Illustrative gameplay example: an entity owns a health-change event; a HUD subscribes while attached and unsubscribes on detach. Specify whether damage triggers immediate nested callbacks or queues a tick-end notification, and whether the HUD receives a snapshot on attach. Removing the HUD during dispatch must follow the chosen in-flight delivery rule.

Counterexample: an order must reserve inventory before confirmation. Two unordered listeners are not a reliable way to express that invariant; keep the sequence with an explicit owner or workflow. A local HUD event does not need a broker or outbox.

## 5. Verify and report

Use the existing harness to check lifecycle teardown/re-subscription, event-time payload stability, dispatch ordering, self-unsubscribe, nested publish, throwing/rejecting listeners, slow-consumer bounds, and snapshot/subscription races as applicable. For durable paths, check commit/rollback, duplicate delivery, and schema compatibility using the relevant integration boundary.

Report publisher/source-of-truth and subscriber lifetime owners, payload and timing contract, ordering/reentrancy/failure rules, delivery guarantees, and checks run or planned. Return the notification decision to `design-for-change`; apply the core quality gate.
