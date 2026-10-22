---
name: design-for-change
description: Code-level design selection before editing — inspect existing conventions, name responsibilities, invariants, state owners, and independent axes of variation, then choose the smallest coherent design and hand off bounded, decision-complete tasks. Use for nontrivial components, features, refactors, or adapters with a real design choice. Skip for trivial typos/renames/config edits or when the existing pattern is unambiguous.
---

# Design for change

Goal: recognize responsibilities and independent variation before coding, choose a cohesive, testable design with repository-specific justification, and hand off bounded work that does not need redesigning.

Load this skill when a change has a real design choice (new component, repeating pattern, unclear boundary, or genuine alternatives). Trivial changes stay direct: typos, renames, config edits, and one unambiguous existing pattern do not need this skill.

## 1. Inspect first
Inspect existing conventions, collaborators, callers, tests, and likely extension requirements. Name what already exists (components, tables, registries, state owners) before proposing anything. Do not invent APIs or layers.

## 2. Name the structure
For each area being touched, answer:
- **Responsibilities** — what each unit owns.
- **Invariants** — what must always remain true.
- **State owners** — who owns each piece of state (source of truth), and where its effects occur.
- **Reasons to change** — why each part exists, so independent variation can be separated from shared behavior.

## 3. Separate independent variation
Do not force discovery, authentication, transport, and lifecycle into one universal interface. Compare only genuinely viable options:

| Variation axis | Default candidate to evaluate | Counterexample to teach |
|---|---|---|
| Same algorithm, different constants | Data/configuration (a table) | Five forwarding classes add no value |
| Different algorithms behind common behavior | Strategy/functions/implementations | A one-off conditional may remain clearer |
| Independent capability combinations | Composition | An inheritance hierarchy creates combinations of combinations |
| Additive behavior around the same caller contract | Evaluate `decorator-pattern` / explicit wrapper order | Fixed helpers or existing middleware may be simpler |
| Different lifecycle/state transitions | Evaluate `state-machine-design` / explicit owners | Strategy alone does not solve shared mutable-state ownership |
| Closed enum and small transformation | Exhaustive match/switch | Dynamic dispatch can obscure a closed auditable state space |
| Construction selection | Small factory/registry if useful | Repeated selection throughout business logic duplicates policy |

For an unresolved concern, use only the focused skill that owns that decision, then return here:

| Concern | Skill |
|---|---|
| Translate an incompatible external/legacy contract | `adapter-pattern` |
| Collaborator injection, captive lifetimes, cycles, or container wiring | `dependency-injection` |
| Ordered transforms, first-handler selection, or around middleware | `pipeline-and-chain-of-responsibility` |
| Represent intent for deferred execution or undo/history | `command-pattern` |
| Notify interested subscribers with explicit lifetime/delivery semantics | `observer-and-events` |
| Uniform leaf/group operations in an owned hierarchy | `composite-pattern` |
| Repeated effects, ambiguous outcomes, retry budgets, deduplication | `idempotency-and-retries` |
| Atomically commit state plus durable publication intent | `transactional-outbox` |
| Cache identity, freshness, invalidation, stampedes, and outage policy | `cache-design` |

Genuine algorithmic/adapter variation behind a meaningful common contract → load `polymorphism-and-strategy` for its focused decision procedure. When legal behavior depends on lifecycle state or event history, use `state-machine-design` to assess fit and resolve the transition contract, then return here. Keep ordinary data transformations as pipelines when they need no lifecycle model; do not load both specialists to decide the same concern.

Independently composable behavior around the same contract → use `decorator-pattern` to assess fit and resolve wrapper contracts, ownership, and ordering, then return here.

## 4. Choose and state the design
- Choose the smallest coherent design that preserves the real invariants; never the most sophisticated or familiar pattern by default.
- State: public contracts, ownership, the construction/dispatch boundary, failure/cancellation behavior, and validation.
- Challenge the design with a **sixth variant** (a simpler option that was dismissed) and an **over-abstraction check** (does every added layer own something real?).

### Construction: Factory, Builder, and composition root

Choose direct construction first. Use a small **Factory** when runtime selection or repeated creation owns real policy; use a **Builder** when staged configuration must establish a valid final object; use the existing **composition root** to wire dependencies and lifetimes. These are separate responsibilities, not a mandatory three-layer stack.

State required inputs/defaults, invalid-combination handling, instance scope, owned versus borrowed resources, and cleanup on partial construction. Keep wrappers/order visible and do not introduce a global service locator. Detailed selection, failure examples, and checks: [references/construction.md](references/construction.md).

## 5. Hand off bounded work
One independently verifiable responsibility per task; serial writers by default. Use the structured handoff in [references/design-handoff.md](references/design-handoff.md) for implementation work — plain-language research briefs remain valid for research. The primary owns design acceptance, shared contracts, integration, and the final gate; workers escalate before changing shared interfaces outside their scope.

Worked examples (explicitly illustrative — not real project APIs): [references/design-examples.md](references/design-examples.md).

## Subagent fan-out

Follow `00-core-global` Skill execution modes. Under **Delegated**: `@explore` for the conventions/callers/state-owner map; `@planner` for the design draft; an independent architecture challenge via the `architecture-reviewer` role when that role is installed (full profile) — otherwise the primary runs the compact challenge inline (responsibilities, alternatives, change impact, testability, speculative abstraction). The primary resolves contracts, ownership, and dependencies. Under **Solo**/Research-assist, perform these steps on the primary.
