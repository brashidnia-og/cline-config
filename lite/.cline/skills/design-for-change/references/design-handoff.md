# Design and task handoff

Structured handoffs carry resolved design decisions into bounded implementation tasks so workers implement without redesigning the feature. Plain-language research briefs remain valid; use this schema for implementation work.

## Schema

```yaml
schema_version: 1        # bump only on breaking changes; an unknown version is a reason to clarify, not to guess
task_id: transport-ble   # unique per task; stable across retries
role: general            # which named role executes (see the profile's agent catalog)
mode: implementation     # research | implementation
objective: Implement one transport against the resolved connection contract.
depends_on: [connection-contract]
design_ref: plan.md#connection-design   # where the resolved decision lives
context: [path/to/interface, path/to/relevant-tests]
owned_files: [path/to/implementation, path/to/implementation-tests]
contracts_and_invariants:
  - Preserve the shared interface and cancellation semantics.
architecture_decisions:
  - Lifecycle state belongs to this transport implementation.
acceptance: [shared behavior, unique failure behavior, no unrelated changes]
validation_commands: []  # populate from inspected project definitions; never invent
model_selection:
  model: null            # explicit user choice, or a capability-verified binding; null = launcher default
  reasoning_effort: null # explicit user choice; null = launcher default
budgets:
  tool_iterations: null  # ceilings, not targets
  wall_clock_seconds: null
escalate_if: [shared interface must change, missing capability, conflicting ownership]
base:                    # include for persisted or concurrent tasks
  revision: <git revision or working-tree identity>
  worktree: <path or "main worktree">
response: [status, changed_files, evidence, test_results, blockers]
```

## Field ownership

- **The primary authors the handoff** and owns `schema_version`, `task_id`, `depends_on`, `design_ref`, `owned_files`, `contracts_and_invariants`, `acceptance`, `validation_commands`, and `escalate_if`. These fields are resolved decisions: “approved design” means the primary has resolved the decision; it is not an extra user-approval prompt for routine reversible work.
- **Workers fill only `response`** and return it. A worker report does not itself satisfy completion; the primary verifies before marking a task done.
- `model_selection` and `budgets` reflect the user's explicit choice or a capability-verified binding; `null` means “launcher default.” An explicitly selected model/effort wins; if the launcher cannot honor it, report the limitation and keep the work on the primary rather than silently using a different model.
- `base` pins the checkout (revision and worktree) for persisted or concurrent tasks so a stale handoff cannot silently target a different checkout. Omit it for ordinary one-shot tasks.

## Escalation

Workers may identify a better design or a missing contract, but must escalate (through `escalate_if` and the report) before changing shared interfaces outside their scope. The primary resolves, updates canonical state, stops dependent work on incompatible contract changes, and revalidates affected completed tasks after contract revisions.

## Task states and persistence

`pending → ready → running → reported → primary-verified`, with `blocked` / `failed` / `cancelled` outcomes. Schedule only `ready` tasks (dependencies resolved). Canonical task state stays single-writer (the primary). Do not automatically create a task database or a `.ai/analysis/` tree for ordinary work; persistent investigations use `checkpointed-analysis` / `persistent-analysis-store` and may link the compact handoff from the store.
