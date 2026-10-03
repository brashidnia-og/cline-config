---
name: game-performance-profiling
description: Measure and improve game frame time, memory, loading, and rendering on target hardware. Use for FPS drops, stutter, mobile performance, expensive AI/physics/rendering, asset budgets, or any claim that a Godot or Unity game change is optimized.
---

# Profile and improve game performance

Treat performance as a measured gameplay constraint. Use the engine skill and its version's official profiler guidance for tool-specific steps. A lower triangle count or cleaner-looking loop is only a hypothesis until measured.

## Measurement loop

1. Read the game's target platforms, quality tiers, player counts, resolution, frame-rate goals, and current budgets. If none exist, state a provisional scenario and budget. A 60 FPS target corresponds to about 16.7 ms per frame, but smoothness and sustained device behavior matter too.
2. Reproduce a representative worst case: actual build and device when possible, fixed map/seed/player count, warm-up, stable camera path, and recorded quality settings. Capture baseline median and slow-frame/p95 frame time, CPU and GPU time where exposed, memory, and relevant workload counts. Distinguish editor, debug, and release measurements.
3. Classify the bottleneck before editing: CPU scripting, physics/AI, rendering/GPU, draw calls/materials, shader/overdraw, allocations/GC, asset loading, memory pressure, or thermal throttling. Use the Godot or Unity profiler and device tools. Record evidence and uncertainty; do not optimize an unmeasured subsystem just because it looks complex.
4. Change one cause at a time. Keep a correctness invariant and a visual/gameplay quality check beside the performance target. Prefer eliminating unnecessary work, reducing frequency or scope, batching/reuse, and fitting assets to visible screen size before broad architecture changes.
5. Repeat the same scenario and compare numbers. If improvement is below measurement noise or harms gameplay/readability, revert or revise. Test more than one relevant device/quality tier when the game targets varied hardware.

## Deliverable

Write a short [performance report](references/performance-report-template.md): scenario and device, build/settings, baseline, bottleneck evidence, change, after measurements, correctness/visual checks, and remaining risks. If a target device is unavailable, label the result as desktop/editor evidence and leave device performance unverified.

For Godot, use its profiler, monitors, render/debug tools, and target-device measurements. For Unity, use the Profiler's CPU/GPU and memory data in a representative player build; verify package/version-specific features in current Unity documentation. Do not mix profiler values from different build settings as if they were comparable.

Official starting points: [Godot general optimization](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html) and [Unity performance profiling](https://docs.unity3d.com/Manual/profiler.html). Check the installed engine version before applying details.
