---
name: polymorphism-and-strategy
description: Decide how genuinely varying behavior should be structured — data/config, functions/strategy, composition, explicit state, factory/registry, or exhaustive match — and state the resulting contract. Use when multiple variants of an algorithm, adapter, or lifecycle would otherwise force growing branches or duplicated decisions. Skip when the variation is constants/configuration or the case set is closed and small.
---

# Polymorphism and strategy

Goal: separate independently changing behavior, rather than eliminating every conditional. “Smallest coherent design” is neither “fewest lines” nor “most classes” — private helpers, switches, and interfaces are choices to justify, not banned or mandatory constructs.

Load this skill when behavior genuinely varies behind a meaningful common contract (different algorithms, adapters, or lifecycles) and the variation is expected to grow. It supplies the variation decision, then returns to its caller (`design-for-change` or the planning skill).

## Decision procedure

1. **Confirm the variation is real.** Would a plausible second variant appear? Would adding one force edits in several places today? If not, a direct implementation (a conditional or helper) stays.
2. **Name the common contract** — the minimum interface callers actually depend on. Do not include capabilities only one variant needs; that variant gets its own interface or extension point.
3. **Pick the lightest structure that owns the variation:**
   - same algorithm, different constants → **data/configuration** (table, resource, config);
   - different algorithms behind common behavior → **strategy**: functions or objects implementing the contract, selected at the dispatch boundary;
   - independent capability combinations → **composition** (reusable parts), not an inheritance hierarchy;
   - different lifecycle/state transitions → use `state-machine-design` to assess fit and define an **explicit state model** with one owner — strategy alone does not solve shared mutable-state ownership; return the lifecycle decision without re-running the broader design selection;
   - closed, small, auditable set → **exhaustive match/switch** at the transition points;
   - construction selection repeated across callers → a **small factory/registry** at the boundary.
4. **State the dispatch.** Who selects which implementation, where the registry/lifetime lives, and what adding a new variant costs (one file, one registration, a closed-set change).
   For translation details use `adapter-pattern`; for Factory/Builder/composition-root scope and partial-construction cleanup, reuse [construction guidance](../design-for-change/references/construction.md). Return those bounded decisions without reselecting the overall design.
5. **State the semantics.** Failure, cancellation, and cleanup behavior per variant, and what is shared versus variant-specific.
6. **Challenge the choice.** Sixth-variant check: is there a simpler structure that was dismissed too early? Over-abstraction check: does the interface own something real (an invariant, a lifecycle, a test seam), or does it only move conditionals around? See the exercise in [references/variation-examples.md](references/variation-examples.md).

Worked choices and counterexamples (explicitly illustrative, not real project APIs): [references/variation-examples.md](references/variation-examples.md).

## Subagent fan-out

Follow `00-core-global` Skill execution modes. Under **Delegated**, `@explore` may map where the variation currently lives (branches, duplication, call sites). The primary makes the structure decision; under **Solo**/Research-assist, work on the primary.
