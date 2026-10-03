---
name: game-reference-to-spec
description: Research mechanics, controls, maps, AI, combat feel, or presentation from reference games and turn observations into an original, testable game feature specification. Use before implementing behavior inspired by another game or reconciling screenshots, videos, notes, and existing design decisions.
---

# Turn game references into buildable specifications

Produce a project-owned feature spec that another agent can implement without guessing what was observed, chosen, or still unknown. Use [the feature-spec template](references/feature-spec-template.md) when the project has no established format.

## Workflow

1. Read the project's design documents, current behavior, constraints, and previous decisions. Identify the feature and the exact sources: game/version, video timestamps, screenshots, play sessions, written notes, or code the user is authorized to inspect.
2. Build an evidence ledger. For each claim, record what was directly observed, the source location, confidence, and conditions (player count, map, character, difficulty, platform). Avoid treating a single frame as proof of a rule.
3. Separate four kinds of statements: **observed reference behavior**, **project decision**, **implementation proposal**, and **unknown**. Do not let an implementation guess silently become a design requirement.
4. Describe the player-visible contract: inputs, state transitions, timing, ranges, collision/scoring effects, feedback, failure modes, and multiplayer interactions. Include edge cases that would change gameplay or fairness.
5. Compare the proposed behavior with the game's current systems. Record what is reused, changed, or intentionally omitted. Preserve an original identity: use the reference to understand mechanics, not to copy art, names, levels, or other expressive assets.
6. Define observable acceptance cases. Prefer examples and small scenario tables over broad adjectives such as “responsive” or “smart.” State the evidence needed to call the feature complete, including an in-game playtest when feel or readability matters.
7. Record open decisions with a recommended default and impact. Ask the user only when two plausible choices would materially change the game; continue independent work on the rest.

## Handoff

The final spec should contain a short objective, source ledger, observed behavior, chosen behavior for this game, invariants, interaction/edge-case table, acceptance cases, unresolved decisions, and links to related docs. Give every rule one owner or source of truth. Update the project's existing GDD/decision log instead of creating conflicting documents.

If implementation is requested, hand the approved or sufficiently specified behavior to `gameplay-code-quality` and the applicable engine skill. Do not claim a reference is faithfully reproduced unless the observed and implemented cases have been compared in play.

## Example

[Arena-game-v1](references/arena-game-v1.md) shows how reference-derived maps, combat, and bot behavior were recorded with evidence and tested in a real Godot project.
