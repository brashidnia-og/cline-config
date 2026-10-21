---
name: state-machine-design
description: Recognize, design, review, and incrementally refactor state machines for business logic, data processing, and gameplay. Use when legal actions depend on lifecycle state or event history, interacting flags allow impossible combinations, or callbacks and timers scatter transitions. Compare with pipelines, strategies, and simple conditionals; do not prescribe a machine merely because a function is large or has several branches.
---

# State machine design

Make behavior over time explicit: which events are legal, which transitions they cause, and who owns state and effects. A switch or map of private handlers can already be a good state machine. Judge the behavioral contract, not the number of classes or conditionals.

## Decide whether it fits

Respect the requested mode: analysis/review identifies candidates without rewriting them; implementation changes only the authorized feature. When called by `design-for-change` or `polymorphism-and-strategy`, resolve the lifecycle decision and return it to the caller; do not restart the broader design process.

Inspect the actual state fields and writes, callers, callbacks, timers, failures, and tests. Ask:

- Does the same event have different legal outcomes depending on the current mode or earlier events?
- Are mutually exclusive modes represented by interacting flags or duplicated checks?
- Must ordering, interruption, retry, or cleanup rules hold across several entry points?

These are evidence to evaluate, not automatic triggers for a rewrite. A straight transformation pipeline, configurable algorithm, derived value, or small clear conditional may already be the right design. For uncertain fit or representation choices, read [recognition-and-modeling.md](references/recognition-and-modeling.md). State the candidate, the invariant it would enforce, and why the simpler alternative does or does not suffice. A justified decision to keep the code is a valid result.

## Define the transition contract

Before implementation, record the following at a scale appropriate to the feature:

- **Owner and scope:** the entity/process modeled and the one authority allowed to commit transitions. Separate independent dimensions; one active leaf per exclusive region does not mean one state for the whole application.
- **States and data:** meaningful behavioral modes, initial state, intentional terminal states if any, and data valid in each state. Use enums, sealed types, or discriminated unions as the repository supports them; keep values such as progress and velocity as data unless they change event handling.
- **Events:** semantic inputs, completions, failures, timer expirations, and cancellation, with validated payloads and correlation identifiers where needed.
- **Transitions:** source + event + optional guard → target + data update + effects. Include important paths in a transition table; use a diagram when it clarifies hierarchy or interruptions.
- **Selection:** pure guards; either mutually exclusive alternatives or explicit priority. Define unsupported-event handling (ignore, reject, defer) and distinguish no change from a self-transition that exits and re-enters.
- **Execution:** effect ordering, failure behavior, entry/exit lifecycle, and ownership of timers/subscriptions/in-flight work. Define how work completes and how stale completion is recognized after exit or a later attempt.

Choose event-processing semantics explicitly. Prefer serialized event handling per owner; callbacks request transitions through that owner. Prevent recursive transitions from observing half-completed exits/entries. Bound immediate transition chains and queued work where the runtime requires it. Run-to-completion of transition logic does not mean blocking on network or long-running work.

## Choose and implement the smallest representation

An exhaustive transition function or small table is often enough. Use state objects when states own substantial distinct behavior or resources. Use hierarchy for genuinely shared transitions, parallel regions for independent lifecycles, and a stack/history mechanism only for defined resume behavior. Reuse an existing machine or engine facility when its semantics fit. Do not introduce a framework, dependency, class per state, or registry by default.

Keep transition decisions testable separately from I/O where useful, for example `transition(state, event) → next state + effect descriptions`. Execute effects at the established boundary and feed outcomes back as events. Entry actions can execute again on re-entry; define which effects may repeat. Changing a state label does not cancel external work, provide authorization, make writes atomic, or guarantee exactly-once execution.

Read only the domain reference needed:

- Existing code, job lifecycles, retries, or durable state → [refactoring-and-testing.md](references/refactoring-and-testing.md).
- Character/AI/combat, game flow, ticks, animation, or pause → [gameplay.md](references/gameplay.md). Use the project's engine conventions and applicable engine skill for APIs and runtime checks.

## Verify and report

Trace consequential event sequences, not only individual handlers. Check state/data invariants, invalid events, competing transitions, interruption, effect failure, and cleanup. For async work, test duplicates and late completion against the current attempt; for persistence, test restart and compatible restore. Use existing project checks and test tools. Stateful/property-based tests are useful when sequence space warrants them, not a mandatory new dependency.

Apply the repository's universal final gate. Report the fit decision, owner, transition contract/representation, behavior changed or preserved, validation evidence, and remaining uncertainty. In review mode, attach concrete paths and triggers to proposed refactors. Do not claim a performance improvement or correctness proof from the diagram or pattern alone.
