---
name: change-planning
description: Plan code changes and implementation designs before editing. Use for implementation plans, design of a feature/fix, sequencing refactors, or when the user asks to plan before coding. Skip for trivial typos/renames/one-line fixes.
---

# Change planning

Goal: produce an implementation-ready plan grounded in the actual repository.

## 1. Contract
Objective, acceptance criteria, non-goals, constraints, unknowns.

## 2. Inspect
Read relevant code, tests, config, and dependency versions. Trace current control/data flow. Do not invent APIs or folders.

## 3. Invariants and ownership
State invariants that must hold. Name state owners/sources of truth and trust boundaries.

## 4. Options
For consequential choices, compare 2 viable approaches briefly and pick one with rationale tied to this repo.

## 5. Sequence
Ordered steps with: files/contracts touched, intended behavior, validation per step, migration/rollback if relevant. No vague “update backend” steps.

## 6. Risks
Compatibility, security, concurrency, failure/partial success, operability.

## 7. Gate
Apply the lite universal gate from `00-core-global`. Label assumptions and unresolved decisions. Do not edit unless the user asks to implement.
