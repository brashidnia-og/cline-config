---
name: persistent-analysis-store
description: >-
  Maintain a structured filesystem knowledge store under .ai/analysis/ for
  long-running repository analysis. Use with checkpointed-analysis, or when asked
  for persistent analysis, external memory, STATE.md, or an analysis datastore.
  Not for ordinary one-shot answers that fit in a single pass.
---

# Persistent analysis store

Goal: keep durable, revisable repository knowledge on disk so many investigation cycles can accumulate an accurate model without reloading everything into context.

## 1. Workspace

State lives in a gitignored `.ai/analysis/` in the **target repo** (never under installed skills dirs):

```text
<target-repo>/.ai/analysis/
  STATE.md
  ARCHITECTURE.md
  COMPONENTS/          # one file per complex subsystem as discovered
  FINDINGS.md
  OPEN_QUESTIONS.md
  DECISIONS.md
  COVERAGE.md
  IMPLEMENTATION_PLAN.md   # when the objective includes planning
```

Create the tree on first use. Add `.ai/analysis/` to the target repo's `.gitignore` if missing.

## 2. File roles

### `STATE.md` (RAM / index)

Primary working-memory index. Keep it roughly short (aim ~2–5k tokens). Continuously rewrite and compress — never a transcript or dump.

Must include:
- current objective,
- subsystem(s) under investigation,
- major established facts (compressed),
- important component dependencies,
- active hypotheses,
- unresolved questions,
- next investigation targets,
- links to detailed store docs needed next.

### `ARCHITECTURE.md`

High-level system model: major components, responsibilities, ownership, data/control flow, lifecycle, concurrency, persistence, external dependencies, init/shutdown. Update in place; do not append duplicate observations.

### `COMPONENTS/`

Create a file only when a subsystem is complex enough to need dedicated notes (for example `streaming.md`, `database.md`). Capture purpose, key symbols/files, callers/callees, data structures, lifecycle, concurrency, ownership, invariants, failure/recovery, and interactions. Cite sources when practical.

### `FINDINGS.md`

Confirmed or strongly supported problems only. Each entry: finding, significance, components, evidence, files/symbols, why it matters, consequences, confidence, remediation if known. Speculation stays in `OPEN_QUESTIONS.md`.

### `OPEN_QUESTIONS.md`

Hypotheses, inconsistencies, validation needs, conflicting evidence. Remove items when resolved and propagate knowledge into the right docs.

### `DECISIONS.md`

Architectural or planning decisions: decision, reasoning, alternatives, constraints, consequences.

### `COVERAGE.md`

Directory/component map with status: `NOT INSPECTED` | `PARTIALLY INSPECTED` | `SUFFICIENTLY INSPECTED` | `REVISIT REQUIRED`, plus a short note on what was examined.

### `IMPLEMENTATION_PLAN.md`

Build only when the objective includes a plan. Grow it as understanding improves; do not finalize early. Capture sequencing, affected contracts, migrations, tests, compatibility, rollout, failure/rollback.

## 3. Confidence labels

Label consequential claims:

| Label | Meaning |
|-------|---------|
| VERIFIED | Established directly from code/config |
| INFERRED | Strongly implied by multiple observations |
| HYPOTHESIS | Needs more investigation |

When a hypothesis is verified, update status and strip speculative wording. Code is authoritative over stale notes — correct the store immediately when they disagree.

## 4. Memory hygiene

The store is a **knowledge base**, not a chronological scratchpad.

Prefer: `StreamCoordinator owns the active cursor and serializes restarts through X.`  
Avoid: `First I looked at StreamCoordinator. Then I noticed X…`

- Consolidate duplicates; replace obsolete conclusions.
- Do not leave unresolved contradictions without calling them out.
- Cite files/classes/methods for important claims when practical.
- If a doc grows too large, split by subsystem and leave summaries + links in higher-level files.

## 5. Selective reads

Do **not** reload the entire store every cycle.

Before investigating a target, read:
1. `STATE.md`,
2. relevant `COMPONENTS/*.md`,
3. only the needed sections of `ARCHITECTURE.md` / `FINDINGS.md` / `OPEN_QUESTIONS.md`.

Then inspect source. Unrelated store docs stay on disk.

## 6. Write discipline

After each bounded investigation:
1. update the affected component/architecture docs,
2. update findings or open questions,
3. update `COVERAGE.md`,
4. rewrite/compress `STATE.md` with best current understanding and next actions.

Never assume a previous note is still correct without checking code when the claim matters.
