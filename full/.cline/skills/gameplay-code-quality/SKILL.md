---
name: gameplay-code-quality
description: Design and implement clean, lightweight, performance-aware gameplay code with clear state ownership, bounded frame work, useful reuse, and observable tests. Use when adding or refactoring game systems in any engine, especially input, combat, AI, spawning, state machines, or multiplayer rules.
---

# Gameplay code quality

Favor the smallest clear design that meets the game's behavior and target-platform constraints. “Generic” means a real repeated concept has one stable contract; it does not mean building a framework before variation exists.

## Before editing

Read the feature spec, game loop, existing state owners, engine version, target devices, and relevant tests. Trace input → simulation → rendering/feedback for the affected feature. State its invariants and the gameplay state owner. Use the engine's normal lifecycle and data model instead of recreating them.

## Implementation rules

- Keep gameplay decisions separate from visual presentation and platform/input adapters where this reduces coupling. Give one system authority to mutate each important piece of state; other systems observe or request changes through a clear contract.
- Prefer cohesive components and data definitions over repeated branches for every weapon, character, map, or pickup. Introduce a shared abstraction after observing repeated behavior or a concrete upcoming variant. Avoid deep inheritance and broad managers that own unrelated state.
- Make per-frame and per-physics work bounded by the intended player, actor, projectile, and map counts. Cache stable references; avoid repeated scene searches, file I/O, large allocations, and full-world scans in hot paths when a local event, registry, or spatial query suffices.
- Use events for changes that occur occasionally; use polling only for continuously varying state that needs it. Prevent duplicate subscriptions, hidden update loops, and lifetime leaks when scenes/entities enter and leave.
- Handle pause, death, despawn, round reset, scene transition, and reconnect where the feature depends on them. Avoid nondeterministic ordering in scoring or combat resolution; seed randomness in repeatable evaluations.
- Preserve behavior while refactoring. Add tests for consequential invariants and gameplay edges, then run the feature in-engine when timing, camera, input, animation, or feel matters. Do not add tests that only mirror the implementation.
- Do not claim a performance gain from code appearance. If the change is motivated by speed or memory, use `game-performance-profiling` for a baseline and after measurement.

## Review and completion

Check that names explain gameplay intent, dependencies are visible, state transitions have one path, failure cases are handled, and the same rule is not duplicated across scripts. Report behavior changed, tests and playtest evidence, and any unmeasured performance claim. Use the applicable engine skill for engine-specific implementation and validation.

[The arena-game-v1 example](references/arena-game-v1.md) illustrates reusable visual parts, centralized rosters, and behavior evaluation without turning the game into a generic engine.
