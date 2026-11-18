---
name: engineering-decision-analysis
description: Make evidence-backed product and engineering recommendations by comparing viable choices, constraints, opportunity costs, short/long-term effects, two-way-door reversibility and tests that distinguish options. Use for material decisions in requirement discovery, architecture, migrations or major implementations; skip trivial or predetermined choices.
---

# Engineering decision analysis

Purpose: improve **decision quality and auditability**, not imitate lengthy internal reasoning. Return concise evidence and a recommendation; do not generate unverified numeric scores, false certainty or a mandatory matrix for every edit.

## 1. Size the decision
- **Small/reversible**: use established conventions and state a one-line rationale; proceed.
- **Moderate**: compare the two most viable options, constraints and one disconfirming scenario.
- **Major, costly, cross-boundary or difficult to reverse**: gather verified evidence; perform an explicit comparison and independent challenge when available.
- **High-impact product choice or irreversible/unsafe action**: recommend, but obtain the owner decision/authorization; a model recommendation is not approval.

Record who has decision authority. Separate user-valued product outcomes from implementation choices delegated to the engineer.

## 2. Apply hard gates before comparing
Identify the objective, success criteria, constraints and non-negotiable invariants (security, correctness, compatibility, data integrity, operating limits). Reject infeasible options before tradeoff scoring. Establish the real system's baseline and ownership; use `evidence-driven-research` for a consequential unknown, not free-form guesswork.

## 3. Compare a small viable set
Include status quo / smallest change when viable. For each option examine only material dimensions:
- User value and direct benefit; short-term performance, complexity, cost and time to deliver.
- Long-term extensibility, maintenance, migration/lock-in, operability and failure burden.
- Opportunity cost: what valuable work/time/capacity does choosing this displace?
- Reversibility (two-way vs one-way door), cost of rollback, blast radius and data migration.
- Reliability, security, compatibility and adverse scenarios.
- Uncertainty, dependencies and what evidence would reverse the preferred choice.

Prefer qualitative facts or actual measured values over invented weights. Use weights only when explicit stakeholder priorities and commensurable measurements are available; perform a sensitivity check if ranking is close. A longer matrix does not imply a more accurate choice.

## 4. Seek decisive evidence
Ask: what is the cheapest **safe experiment** that would distinguish plausible options? Prototype, A/B benchmark, contract test, or inspect an existing consumer. Do it when cheaper than committed rework. A favorable benchmark on a different device/model is not proof for this deployment. Challenge the preferred option with a realistic counterexample; if no credible test exists, label the uncertainty.

## 5. Recommend and document
For minor cases give a one-line recommendation. For significant cases return this compact decision record:

```text
Decision: [the concrete choice and owner]
Goal / constraints: [measurable target and invariants]
Alternatives: [status quo, A, B; only viable choices]
Tradeoffs: [short term, long term, opportunity cost, reversibility, failure/rollback]
Evidence: [file:line, test, or URL; verified vs inferred]
Recommendation: [one choice and why, including what is sacrificed]
Confidence / unknowns: [what might overturn it]
Next action: [safe experiment, approval, or implementation]
```

For major lasting design choices, persist this as a linked decision entry in the existing project requirements or architectural decision log. Do not duplicate the product contract or substitute for `design-for-change`; use this skill for *choosing* and that one for boundaries, tasks and implementation handoffs. A decision that conflicts with product intent returns to the requirements owner.
