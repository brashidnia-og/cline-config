---
name: pipeline-and-chain-of-responsibility
description: Design, implement, or review ordered processing pipelines, middleware, interceptors, validation stages, and Chain of Responsibility handlers. Use when stage order, short-circuiting, next/delegation, context, or partial failure changes behavior. Distinguish transforming every stage from selecting a handler; skip a simple fixed sequence that needs no extra abstraction.
---

# Pipeline and Chain of Responsibility

Goal: make ordered work and stopping behavior explicit without replacing straightforward control flow with a framework.

## 1. Establish which protocol is needed

Respect the requested mode. Inspect entry points, stage registration, framework versions, callers, and nearby tests before editing. Choose the lightest fit:

| Protocol | Contract |
|---|---|
| Transformation pipeline | Each reached stage transforms the previous result into the next input |
| Chain of Responsibility | A handler handles, rejects, or explicitly passes; define whether the first match wins |
| Around middleware | A layer may invoke `next` and unwind result/error/cleanup afterward |
| Direct sequence | A few fixed calls are clearer without reusable stage objects |

Reuse native middleware/interceptors when their lifecycle fits. Use `decorator-pattern` for substitutable component wrapping and `state-machine-design` only when legal transitions depend on event history; neither is required merely because several stages exist.

## 2. Write the flow contract

- Show the actual ordered stages and why order matters. Include success, rejection, failure, cancellation, and no-handler/no-result paths.
- Define stage input/output types and context ownership. Prefer explicit stage-specific types over a mutable bag containing fields that may or may not exist.
- Distinguish handled, pass, rejected, and failed outcomes; `null` or `false` should not ambiguously mean all four. State whether validation accumulates errors or stops early.
- Specify whether `next` may be called zero or once; multiple calls require an explicit protocol. Define what happens when a stage returns without awaiting async downstream work.
- State which stages are mandatory on every entry path. Authorization, limits, and audit obligations must not depend on an optional handler happening to run.

## 3. Own state and effects

- Construct order at one existing registration boundary; do not rely on filesystem order or incidental container registration. Reject invalid or duplicate registrations when they would change correctness.
- Keep per-request context isolated from reusable stage instances. Define mutation, concurrency, reentrancy, and thread/task context propagation.
- State the transaction boundary. A later failure does not automatically undo earlier writes or external effects; use transactions or explicit compensation only where required.
- Assign retry ownership. Retrying the whole pipeline can repeat validation, audit entries, and irreversible effects; use `idempotency-and-retries` for that decision.
- Bound queue sizes, in-flight work, handler traversal, and input size as relevant. Preserve streaming/backpressure rather than collecting unbounded data between stages.
- Propagate cancellation and deadlines; distinguish a cancellation token from a guaranteed time budget. Unwind cleanup for entered stages without masking the primary error.
- Define whether stage errors are propagated, translated, isolated, or collected; do not silently continue after a broken mandatory stage.

## 4. Trace an example before coding

Illustrative first-match import chain: `RecognizeCsv → RecognizeJson → UnsupportedFormat`. A non-CSV input passes; malformed recognized CSV fails instead of falling through as though it were JSON. The terminal handler returns an explicit unsupported-format result. A separate pipeline can then validate and persist the parsed record.

Illustrative around middleware: `Trace → Authorize → Handler`. Request flow goes inward; awaited result/error and cleanup unwind outward. Show whether trace includes rejected authorization. Returning a promise without awaiting can change cleanup/timing scope in some languages; inspect the actual protocol.

Counterexample: three private pure transformations called once in a known order can remain three function calls.

## 5. Verify and report

Use the project's checks for order-sensitive outcomes, handled/pass/rejected/error distinctions, no match, forbidden double-`next`, async completion, cleanup, cancellation, and request-state isolation where applicable. Assert effects and outcomes, not just the order of mocks. Include a failure after an earlier effect when partial success matters.

Report the chosen protocol, ordered flow and stopping rules, context/state owners, side-effect/transaction boundary, registration point, and verification evidence or planned checks. Return only this flow decision to `design-for-change`; apply the core quality gate.
