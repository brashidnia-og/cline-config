---
name: derive-3d-character-specs
description: Derive buildable 3D character definitions from 2D concept art, sprite sheets, or reference images. Use before modeling characters from images or when a roster needs explicit geometry, scale, parts, and uncertainty records.
---

# Derive 3D character specs from images

Turn visual references into an explicit, reviewable handoff for `build-3d-game-characters`. Do not create meshes in this phase.

## Workflow

1. Inspect every source image at its actual resolution. Record its path, dimensions, hash, intended use, and any rights/usage information supplied by the project. Crop a crowded sheet into per-character references if that improves inspection; keep the original.
2. Identify the complete roster in source order. Record labels exactly, then assign stable lowercase IDs. Do not infer hidden characters from an unclear crop.
3. For each character, separate **observed** features from **authored interpretations**. Record body silhouette and proportions, palette, face, limbs, accessories, distinctive front details, and what is visible of side/back. A frontal image never proves unseen depth or back design.
4. Write a 3D construction recipe: body primitive/profile or sculpt strategy, front-to-back depth, separate pieces, materials, face and limb anchor positions, local forward direction, and ground contact. Describe how silhouette-critical features remain readable from the game's camera.
5. Define a shared visual contract for the roster: units, up/forward axes, root and part names, expected animation interface, collision separation, approximate asset budgets, and export format. Inspect the target game first; use its existing contract if one exists.
6. Mark unresolved design decisions and confidence per character. Ask for a turnaround or approval only when the ambiguity would produce fundamentally different designs. Continue with the smallest documented interpretation for minor gaps.
7. Compare the specs side by side for coherent scale, face size, limb width, materials, and silhouette diversity. Verify the roster count and image-to-spec mapping.

## Required handoff

Write a project-owned `character_specs.json` using [the example schema](references/character-spec-example.json) as a shape guide, plus a short readable `CHARACTER_MODEL_PLAN.md` with one recipe per character. Include `schema_version`, source evidence, roster order, shared contract, and each character's observed/assumed features. Keep project-specific names and dimensions out of this reusable skill.

Each character must include: `id`, `display_name`, `source_region`, `observed`, `interpretations`, `construction`, `anchors`, `uncertainties`, and `status`. Use `status: "spec_ready"` only after the spec can be modeled without re-reading the original conversation.

Run the companion validator from the installed `build-3d-game-characters` skill when available. Finally, inspect the written JSON and readable plan against the image. A valid JSON file alone does not prove visual fidelity.

## Reference case

[The arena-game-v1 case study](references/arena-game-v1.md) shows how a small frontal sheet became an 18-character map and procedural body recipes. It also records which side/back details were invented.
