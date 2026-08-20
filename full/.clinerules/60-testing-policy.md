# Testing and verification policy

Testing exists to prove meaningful behavior and reduce regression risk, not to maximize coverage mechanically.

## Behavior-first loop
For observable behavior changes, prefer:
1. identify the acceptance criterion or reproduce the defect,
2. create/update the narrowest meaningful test when practical,
3. confirm the test fails for the expected reason on the defective behavior when feasible,
4. implement the smallest coherent change,
5. confirm the test passes,
6. refactor only while preserving behavior,
7. broaden validation according to risk.

If a pre-change automated test is impractical, explain why internally and use the strongest available verification.

## Test selection
Prioritize:
- critical paths and domain invariants,
- negative/failure paths,
- boundary/null/empty/invalid values,
- auth/ownership boundaries,
- retries/idempotency/duplicates,
- transaction rollback/partial failure,
- serialization/backward compatibility,
- cancellation/timeouts/concurrency where relevant.

Do not spend cycles testing trivial getters/pass-through code unless behavior is non-obvious or regression-prone.

## Test quality
- Assert outcomes/invariants, not merely method invocation.
- Mock external or expensive boundaries when appropriate; avoid mocking the unit's own behavior or internal implementation details.
- Use real database/container integration tests when database constraints, isolation, locking, SQL, or transaction semantics are the subject under test.
- Avoid arbitrary sleeps; use deterministic clocks, barriers, polling-with-deadline, or framework test utilities.
- Do not weaken assertions, delete tests, broaden tolerances, or disable checks simply to make the implementation pass.
- Passing tests do not excuse missing contract/security/compatibility reasoning.

Use repository-established test libraries before adding new ones.

## Validation report
Before saying work is complete, know exactly which targeted tests, compilation/type checks, lint/static checks, integration tests, and broader suites ran and whether each passed, failed, or was skipped.

For complex test design, concurrency stress tests, flaky tests, or integration strategy, activate the `test-engineering` skill.
