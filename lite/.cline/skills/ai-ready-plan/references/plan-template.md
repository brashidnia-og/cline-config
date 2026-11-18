# Plan: <feature name>

**Status:** clarifying | blocked | ready
**Slug:** <kebab-slug>

Status is `ready` only when every MUST criterion is testable, every task is executable, and Open decisions is `none`.

## 1. Source

**Request:** <user's words, unchanged>

**Decisions**

| ID | Decision | Source |
|---|---|---|
| D-1 | <what was settled> | user \| assumed \| inspected |

**Open decisions:** `none`, or one row per blocker: id, the criterion it blocks, who must answer.

## 2. Outcome

<One paragraph: actor, observable result, and why this change exists.>

## 3. Acceptance criteria

### AC-1: <name> — MUST | SHOULD

**Requirement:** When <trigger>, the <system> shall <observable result>.
**Given** <state>
**When** <action>
**Then** <named result: response, state, record, or UI>
**Evidence:** <existing test path, new test name to add, or manual check>
**Delta:** added | modified

Add a criterion for the unhappy path that the clarification round selected. A criterion that cannot be failed on purpose is not done.

## 4. Non-goals

- <nearby behavior this plan must not implement>

## 5. Current behavior

<What happens today, with repo paths. Label Unknown where the code was not read.>

## 6. Regression contract

| ID | Unchanged behavior | Why it is at risk | Existing proof | Required proof |
|---|---|---|---|---|
| RG-1 | <observable behavior that must survive> | <shared caller, state, schema, or contract> | <test path or none> | <keep, add characterization test, or manual check> |

A single row may say no shared risk. It must cite the inspection that shows the change cannot affect other callers, state, or contracts.

## 7. Delta

- **Added:** <new observables, AC ids>
- **Modified:** <changed observables, AC ids>
- **Unchanged:** <RG ids>

## 8. Decisions that bind implementation

Resolved design only. Each item names the inspection or the skill that settled it (`design-for-change`, `architecture-review`, or a cited path).

- **Ownership and invariants:**
- **Contracts affected:** APIs, schema, events, config, persisted formats
- **Failure and rollback:** what is atomic, what is retried, what is left unchanged
- **Compatibility:** mixed versions, old data, old callers

Product choices that are still open belong in section 1, not here.

## 9. Tasks

Implement in listed order. A task whose `depends_on` is unfinished is not ready.

### T1: <name>

```yaml
task_id: t1-<slug>
role: general
mode: implementation
objective: <one verifiable outcome>
depends_on: []
design_ref: plans/<slug>.md#8
ac_ids: [AC-1]
regression_ids: [RG-1]
context: [<existing paths>]
owned_files: [<paths this task may edit>]
contracts_and_invariants:
  - <what must remain true>
architecture_decisions:
  - <decision already made; not a choice for the implementer>
acceptance:
  - <observable result tied to AC-1>
validation_commands:
  - <command copied from the repo, or "manual: <check>">
escalate_if:
  - a shared contract must change
  - an open decision blocks the task
  - a listed path does not exist
  - validation fails
```

## 10. Validation map

| ID | Proof |
|---|---|
| AC-1 | <command or manual check> |
| RG-1 | <command or manual check> |

## 11. Agent execution rules

Copy this section into every plan unchanged.

- Implement only the task id you were given. Leave later tasks untouched.
- Acceptance criteria are the behavior contract. Regression rows are obligations. Both bind.
- Do not add behavior that has no AC id. Do not change a behavior that an RG row protects except to keep it unchanged.
- Edit only `owned_files`. When a shared contract, missing capability, or conflicting ownership matches `escalate_if`, stop and report. Do not redesign.
- Do not resolve an Open decision. Stop and ask.
- A decision labeled Assumed is binding. If the repo contradicts it, stop and report the contradiction.
- Prove the task's AC ids and the RG ids it can affect. Use the listed validation commands. Do not invent commands, paths, or dependencies.
- Report status, changed files, evidence per id, and blockers. Do not mark this plan ready or complete.

## 12. Handoff

```text
Read plans/<slug>.md. Implement task <task_id> only. Follow section 11. Stop on any open decision or escalate_if condition. Report evidence for each AC and RG id on that task.
```
