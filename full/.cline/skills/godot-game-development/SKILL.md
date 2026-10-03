---
name: godot-game-development
description: Implement and validate gameplay features in an existing Godot project using its scene, resource, GDScript or C#, input, physics, rendering, and export conventions. Use for Godot game systems, scenes, characters, maps, AI, UI, or platform builds; pair with game-performance-profiling when speed or memory is a goal.
---

# Godot game development

Use the installed Godot version and the project's own conventions. Check current official Godot documentation for version-sensitive APIs, rendering settings, or import/export behavior before coding.

## Inspect first

Read `project.godot`, relevant scenes/scripts/resources, autoloads, plugins, input actions, collision layers, rendering method, target platforms, and established test commands. Find the real gameplay entry point and state owner. Preserve scene ownership, node paths, resource IDs, and unrelated edits.

## Build the feature

1. Apply `game-reference-to-spec` when behavior comes from a reference game; apply `gameplay-code-quality` for state and component design.
2. Place reusable behavior in the smallest suitable scene, script, or resource. Keep authored data in resources or registries when many variants share behavior. Use signals or explicit calls according to ownership and lifetime; disconnect or free correctly.
3. Put fixed-step simulation and collision decisions in physics processing when appropriate; keep visual interpolation and presentation separate. Respect delta time, pauses, scene transitions, and input ownership. Do not infer gameplay collision from art meshes without a design reason.
4. Reuse the project's controller, camera, animation, graphics profiles, and asset pipeline. Test imported assets and scenes in the actual renderer; headless checks cannot establish visual quality.
5. For performance-sensitive features, record the expected maximum actor count and target device. Keep hot-path work bounded, then profile rather than assuming an optimization worked.

## Verification

Run the narrowest existing headless scene/script checks that prove structure and gameplay invariants. Launch the relevant scene for controls, camera, animation, readability, and visual effects. If targeting mobile or another constrained device, verify a build there when available; record when only desktop/headless evidence exists. Report the Godot version, scene tested, observed behavior, and remaining device or multiplayer gaps.

## Reference

[Arena-game-v1](references/arena-game-v1.md) shows a Godot 4.7 mobile-renderer project with automated checks and windowed capture. Adapt its validation pattern, not its game-specific rules.
