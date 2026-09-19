---
name: deep-debugging
description: Hypothesis-driven root-cause debugging for bugs, crashes, flaky tests, unexpected behavior, or failures that resist a simple fix. Use when asked to debug, diagnose, find root cause, or investigate an error. Skip for trivial typos/renames/one-line fixes.
---

# Deep debugging

Goal: fix the root cause, not only the symptom.

## Subagent fan-out
Follow `00-core-global` Skill execution. Under **Delegated**: `@debugger` for causal diagnosis (hypothesis digest); `@explore` for callers/paths; `@scout` for upstream known issues when useful. Lite has no shell/browser agents—run repro/tests on primary (or Research-assist search only on Cline). Primary keeps the hypothesis ledger and applies the single coherent fix (or `@general` if handing off an isolated edit). Under **Solo**, do all steps here.

## 1. Establish the failure
Capture symptom, expected behavior, environment, and whether it is deterministic. Reproduce with the narrowest command/test when feasible.

## 2. Trace
Follow entry → failure and upstream to bad state (callers, parsers, state writes, async consumers, config). Do not stop at the first throw.

## 3. Hypothesis ledger
Keep a compact ledger: Hypothesis | Evidence for | Evidence against | Cheapest discriminating test | Status. Falsify aggressively; one experiment per question.

## 4. Fix discipline
State root-cause hypothesis and invariant violated. Apply one coherent causal fix. After two failed edit attempts, stop speculative editing, revert experiments safely, rebuild the model, then design a new discriminating test.

## 5. Verify
Narrow → broad: regression test, affected unit/integration, typecheck/lint, broader suite if needed. Prefer a test that fails on the old bug and passes after the fix.

## 6. Gate
Apply the lite universal gate from `00-core-global`. Report cause, evidence, change, validation, and remaining uncertainty.
