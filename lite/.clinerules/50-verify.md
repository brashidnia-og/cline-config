# Verification (lite)

Testing proves meaningful behavior; it does not maximize coverage mechanically.

## Behavior-first
1. Identify acceptance criterion or reproduce the defect.
2. Prefer the narrowest meaningful test or check.
3. Implement the smallest coherent change.
4. Confirm the check passes for the right reason.
5. Broaden validation according to risk.

## Quality
- Assert outcomes/invariants, not internal call sequences.
- Do not weaken, delete, or disable checks merely to make work pass.
- Prefer repository test libraries; do not invent a new stack.
- Passing tests are evidence, not proof.

## Report
Before claiming complete, know which targeted tests, typechecks, lints, and broader suites ran and whether each passed, failed, or was skipped.
