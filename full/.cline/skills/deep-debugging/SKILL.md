---
name: deep-debugging
description: Perform hypothesis-driven root-cause debugging for bugs, crashes, flaky tests, race conditions, data corruption, unexpected behavior, performance anomalies, or failures that resist a straightforward fix. Use when the user asks to debug, diagnose, find the root cause, investigate an error, or fix a complex failure. Skip for trivial typos/renames/one-line copy fixes.
---

# Deep debugging

Goal: establish the causal chain and fix the root cause rather than patching the visible symptom.

## 1. Establish the failure

Before editing when feasible:
- capture the exact symptom, failing input, error/stack trace, environment, and expected behavior,
- identify whether failure is deterministic, intermittent, data-dependent, timing-dependent, environment-specific, or version-specific,
- reproduce with the narrowest command/test possible,
- distinguish symptom, trigger, contributing condition, and root cause.

If reproduction is impossible, state which evidence is indirect and design the next best observation.

## 2. Trace the causal path

Trace from entry point to failure and upstream to the origin of bad state:
- callers/callees,
- parsers/mappers/validation,
- state reads/writes,
- transaction boundaries,
- caches/serialization,
- async/background consumers,
- external dependency responses,
- configuration/version behavior.

Do not stop at the first throwing line.

## 3. Hypothesis ledger

When evidence is not decisive, maintain a compact ledger:

| Hypothesis | Evidence for | Evidence against | Cheapest discriminating test | Status |
|---|---|---|---|---|

Generate only plausible hypotheses. Rank by evidence and likelihood; do not manufacture “creative” possibilities to satisfy a quota. Falsify aggressively and remove rejected hypotheses.

Each experiment should answer a specific question and ideally produce different outcomes for competing hypotheses.

## 4. Concurrency/timing failures

For races/deadlocks/stale state:
- enumerate concurrent entry points/workers/listeners/requests,
- map shared mutable state and synchronization,
- identify transaction/isolation/lock boundaries,
- look for check-then-act windows, lost updates, non-atomic state transitions, visibility/cancellation issues,
- prefer deterministic barriers/latches/test clocks over arbitrary sleeps,
- repeat stress tests enough to be meaningful while keeping assertions deterministic,
- verify invariants at the database/state level, not only returned values.

## 5. Environment/version failures

Compare:
- dependency/toolchain versions,
- runtime flags/env/config,
- schema/migrations,
- generated artifacts,
- last-known-good commit/change when useful.

Use external-context7 / local-context7 for exact library/framework semantics at the installed version. Use external-brave-search / external-tavily for current official known issues/advisories/release notes after sanitizing errors. External reports are hypotheses until local evidence connects them to this failure.

## 6. Browser failures

Prefer local-playwright to reproduce a deterministic user flow and inspect semantic UI state.
Use local-chrome-devtools for console, network, runtime, source-map, and performance evidence.
Use both when the functional sequence and low-level browser evidence are both required.

Do not expose real tokens/cookies/customer data. Prefer test accounts/non-production state.

## 7. Fix discipline

Before changing code, state internally:
- root-cause hypothesis,
- invariant/contract violated,
- why the proposed change addresses the cause,
- regression test or verification that should fail before/fix after.

Apply one coherent causal fix. Avoid changing multiple independent variables merely to see what sticks.

## 8. Failed-attempt recovery

After two unsuccessful implementation attempts, stop speculative editing—not the investigation.

Then:
1. isolate/revert failed experimental edits without disturbing user work,
2. re-read the original symptom and exact outputs,
3. rebuild the causal model from entry point through state changes,
4. update the hypothesis ledger using new evidence,
5. inspect missing callers/config/version/data paths,
6. design a new discriminating experiment before another edit.

Escalate to the user only when progress requires unavailable access/data/credentials or a product decision.

## 9. Verification

Use narrow → broad validation:
- regression/reproduction test,
- affected unit/integration tests,
- compile/type-check/static analysis,
- broader affected module/suite,
- browser/runtime verification if relevant.

When feasible verify the regression test fails on the old behavior and passes after the fix.
Search for the same defect pattern in nearby code when the root cause is systemic.

## 10. Final gate

Apply the universal quality gate from `00-core-global`. Confirm the fix addresses root cause (not only the symptom), validation can fail on the old bug, and no temporary instrumentation remains.

Report cause, evidence, change, validation results, and remaining uncertainty.
