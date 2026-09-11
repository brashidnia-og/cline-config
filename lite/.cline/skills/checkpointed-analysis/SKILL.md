---
name: checkpointed-analysis
description: >-
  Run long-running checkpointed investigation with persistent external memory.
  Use when asked for checkpointing, checkpointed analysis, persistent analysis,
  deep codebase investigation, large feature planning, or work too large for one
  model context. Compose with domain skills (architecture-review, deep-debugging,
  security-audit-core, change-planning). Skip trivial typos/renames/one-line fixes.
---

# Checkpointed analysis

Goal: complete large investigations through many bounded cycles, writing durable knowledge to disk so the model never has to hold the whole repository model in context.

## 1. Activate store first

Immediately load `persistent-analysis-store` and use `.ai/analysis/` as durable memory for the rest of the task.

Optionally load **one** domain skill that matches the objective (for example `architecture-review`, `deep-debugging`, `change-planning`, or `security-audit-core` + one stack audit skill). Do not load multiple competing domain skills in one pass.

## 2. Investigation cycle

Repeat until the user's objective is satisfied or further progress is blocked by unavailable information:

1. **Orient** — read `STATE.md` and only the store docs needed for the current target.
2. **Choose** — pick one bounded investigation target (one component, call chain, hypothesis, or uncovered area).
3. **Investigate** — search and read code; follow important dependencies; verify prior assumptions against source.
4. **Reason** — form conclusions for that target only; do not try to finish the whole task in one pass.
5. **Checkpoint** — persist verified knowledge, correct stale notes, update findings/questions/coverage, rewrite `STATE.md` with the next highest-value target.
6. **Continue** — start the next cycle.

## 3. Semantic checkpoints (not token counts)

Checkpoint after meaningful progress, for example:
- finishing a component or call-chain investigation,
- resolving or falsifying a hypothesis,
- discovering an important architecture relationship or bug,
- before switching subsystems,
- before synthesis, implementation, or a major plan revision,
- before context is likely to compact or drop earlier turns.

Do **not** checkpoint on a fixed reasoning-token interval. The agent cannot reliably count hidden reasoning tokens, and that couples the workflow to model-server internals.

## 4. Continuation rule (load-bearing)

Checkpointing is an **intermediate** operation, not task completion.

**DO NOT stop after writing a checkpoint.** After every checkpoint:
1. inspect `STATE.md`,
2. select the next unresolved / highest-value target,
3. continue investigating.

Stop only when:
- the user's requested objective is satisfied, or
- further progress is blocked by unavailable information (state that blocker clearly).

Never treat “I saved notes to STATE.md” as done.

## 5. What to persist vs keep ephemeral

Persist conclusions, evidence, relationships, hypotheses, decisions, coverage, and source references.

Do **not** store raw chain-of-thought or chronological “first I looked at…” transcripts.

Treat conversation context as temporary working memory; treat `.ai/analysis/` as long-term memory. If a fact may matter in a later cycle, write it down.

## 6. Synthesis and handoff

When investigation coverage is sufficient for the objective:
- consolidate contradictions in the store,
- synthesize from accumulated docs (not only the last files read),
- write or revise `IMPLEMENTATION_PLAN.md` when the objective includes a plan,
- apply the profile universal quality gate before the final answer.

Report what was verified, what remains open, and which store paths hold the durable record.
