---
name: test-engineering
description: Design, improve, or diagnose complex automated tests and validation strategy. Use for integration tests, Testcontainers, browser/E2E tests, concurrency stress tests, property-based tests, flaky tests, test architecture, coverage of risky behavior, or when the user explicitly asks for a comprehensive test plan. Skip for trivial typos/renames/one-line copy fixes.
---

# Test engineering

Goal: build tests that meaningfully falsify incorrect implementations and remain deterministic, maintainable, and proportional to risk.

## 1. Start from behavior/invariants

Identify:
- acceptance criteria,
- observable contracts,
- critical invariants,
- likely regression/failure modes,
- boundaries that require real integration rather than mocks.

Do not start from “achieve N% coverage”.

## 2. Choose the right test level

Prefer the lowest level that proves the behavior without hiding the relevant mechanism:
- **Unit:** pure/business logic and isolated policy.
- **Integration:** DB constraints/queries/transactions, serialization, actual adapters, framework wiring.
- **Contract:** producer/consumer or external API compatibility.
- **Browser/E2E:** critical user flow across real boundaries.
- **Property-based:** broad invariants over large input spaces, especially parsers/math/financial logic.
- **Concurrency stress:** races/locking/ordering/visibility.

Do not mock the behavior under test.

## 3. Test quality

Tests should:
- fail for the intended defect,
- assert outcomes/invariants rather than internal call sequences,
- use descriptive behavior names,
- make setup/inputs intentional,
- isolate external nondeterminism,
- avoid arbitrary sleeps,
- avoid order dependence/shared mutable fixtures,
- preserve useful failure diagnostics.

Use repository-established frameworks before adding dependencies.

## 4. Database integration

When DB semantics matter, use the real DB engine/version as closely as practical (e.g. existing Testcontainers).
Test:
- constraints and null/default behavior,
- transaction commit/rollback,
- isolation/locking when relevant,
- indexes/query semantics where correctness/performance depends on them,
- migrations against realistic old schema/data.

Do not replace a DB integration test with repository mocks when the defect is in SQL/constraints/transactions.

## 5. Concurrency tests

Avoid “spawn 20 threads and sleep”. Prefer:
- controlled barriers/latches,
- deterministic scheduling hooks where available,
- repeated execution with bounded deadlines,
- invariant checks against final durable state,
- independent worker errors captured and asserted,
- test clocks for time-based behavior.

A stress test can complement but not replace a deterministic reproduction when one is possible.

## 6. Browser tests

Use Playwright MCP to explore/reproduce a flow before encoding it in repository-owned tests. Prefer semantic roles/labels and stable user-facing behavior over CSS/XPath implementation details.

Use Chrome DevTools MCP for network/console/runtime evidence when a browser test fails for reasons not visible in the DOM.

MCP interaction is diagnostic evidence; durable regressions should live in repository tests when appropriate.

## 7. Language/toolchain guidance

### TypeScript/JavaScript
Use the existing Vitest/Jest/Testing Library/MSW stack if present. Prefer user-visible assertions for components. Avoid globally mocking `fetch` when the repository uses MSW or an equivalent boundary abstraction.

### Kotlin/JVM
Use the repository's JUnit/MockK/Mockito/AssertJ/etc. conventions. For coroutines use the repository's coroutine-test utilities and virtual/test time where possible. Use Testcontainers for DB semantics when already established.

### Rust
Keep unit tests near modules when conventional and integration tests under `tests/` when appropriate. Prefer real structures over unnecessary trait mocks. Use property tests when invariants benefit from generated inputs and the repo already supports or justifiably needs them.

## 8. Flaky-test diagnosis

Classify flakiness: time, concurrency, environment, ordering, external service, shared state, random seed, resource pressure, or test isolation.
Capture the actual failure distribution and remove nondeterminism instead of increasing timeouts blindly.

## 9. Validation strategy

Order tests to discover risk cheaply:
- regression/targeted test,
- affected unit/integration tests,
- compiler/type checker/static analysis,
- module suite,
- broader suite/E2E when warranted.

## 10. Final gate

Apply the universal quality gate from `00-core-global`. Confirm tests would fail on incorrect implementations, mocks do not hide the behavior under test, and coverage was not weakened to pass.

Report exactly what the tests prove and what remains unverified.
