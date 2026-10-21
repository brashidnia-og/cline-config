---
name: change-planning
description: Plan code changes and implementation designs before editing. Use for implementation plans, design of a feature/fix, sequencing refactors, or when the user asks to plan before coding. Skip for trivial typos/renames/one-line fixes.
---

# Change planning

Goal: produce an implementation-ready plan grounded in the actual repository.

## Subagent fan-out
Follow `00-core-global` Skill execution. Under **Delegated**: `@explore` for map/paths; `@planner` for the phased plan draft; `@scout` if external deps/docs matter. Primary merges options, risks, and the gate—do not let `@general` own planning. Under **Solo**, do all steps here.

## 1. Contract
Objective, acceptance criteria, non-goals, constraints, unknowns.

## 2. Inspect
Read relevant code, tests, config, and dependency versions. Trace current control/data flow. Do not invent APIs or folders.

## 3. Invariants and ownership
State invariants that must hold. Name state owners/sources of truth and trust boundaries.

## 4. Options and variation
Separate shared behavior from independent variation (constants vs algorithms vs capabilities vs lifecycle). For a real design choice, run the `design-for-change` procedure (installed alongside this skill): inspect conventions, name responsibilities/invariants/state owners, compare only genuinely viable options, pick the smallest coherent design, and challenge it with a sixth variant. For genuine algorithm/adapter variation behind a common contract, use `polymorphism-and-strategy`; for lifecycle/event-order rules or scattered transitions, use `state-machine-design` to assess fit and define the transition contract, then return here. Keep each comparison brief and tie the rationale to this repo.

## 5. Sequence
Ordered steps with: files/contracts touched, intended behavior, validation per step, migration/rollback if relevant. No vague “update backend” steps. If implementation follows, emit one bounded task per independently verifiable responsibility using the compact handoff from `design-for-change` (`references/design-handoff.md`): objective, owned files, contracts/invariants, acceptance, escalation. Plain-language briefs are fine for research.

## 6. Risks
Compatibility, security, concurrency, failure/partial success, operability.

## 7. Gate
Apply the lite universal gate from `00-core-global`. Label assumptions and unresolved decisions. Do not edit unless the user asks to implement.
