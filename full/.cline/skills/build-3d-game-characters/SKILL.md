---
name: build-3d-game-characters
description: Build, export, integrate, inspect, and revise a roster of stylized 3D game characters from explicit character specs. Use for reproducible character asset production, shared rig or pivot animation, and playable in-engine character QA.
---

# Build 3D game characters

Use this after `derive-3d-character-specs`, or after receiving equivalent project-owned specs. Own the entire production loop through in-engine inspection. A mesh export alone is not completion.

## Start and resume

1. Read project instructions, existing character specs, art sources, engine version, player controller, camera, input, asset limits, and git status. Preserve unrelated work.
2. Locate `character_specs.json` and run `python3 scripts/validate_character_specs.py <path>`. If the project uses another format, normalize it or document an equivalent complete contract before modeling.
3. Read or create `CHARACTER_BUILD_STATUS.md` and `CHARACTER_WORKLOG.md`. On every resumed session, read them before starting another character. Track `not_started`, `in_progress`, `needs_revision`, `done`, or `blocked` for each asset.
4. Choose the most reliable available production route. Prefer deterministic primitive/profile modeling for simple stylized shapes; use Blender and editable `.blend`/Python sources when available and useful. Image-to-3D can supply a difficult body, but inspect and clean topology, separate limbs, and preserve an editable source. Do not require a paid service.

## Establish the shared system

Build one representative character completely before scaling the roster. Define units, up/forward axes, feet at ground, root/part naming, face and limb anchors, color accents, material conventions, GLB export, and runtime animation interface. Reuse the game's player controller and simple gameplay collision; swap visuals without silently changing movement or hitboxes.

For simple food/object characters, share face, arms, feet, and motion vocabulary where it suits the design. A rigid-part pivot rig is valid when skin deformation is unnecessary. Do not call it a skinned skeleton. Typical animation states are idle, walk, run, attack, hit, death, and victory; map to existing game states where names differ.

## Production loop for every character

1. Read its observed features and documented interpretations. Build the body and distinctive accessories at the agreed scale. Keep source code or editable project files with the export.
2. Export GLB (or the project's format) and import it into the engine. Check node names, transforms, materials, bounds, missing resources, and realistic game-camera readability.
3. Render front, front three-quarter, side, back, and game-camera views under repeatable lighting. Compare with the source and spec. Inspect silhouette, face, proportions, limb anchors, palette, foot contact, shading, and animation clipping.
4. Make at least one deliberate inspection/revision decision, recording what changed or why the first pass needed no geometry change. Re-export and re-check after changes.
5. Exercise the character in a playable sandbox using the real pawn where possible: move, switch characters, trigger required states, and ensure position/facing and collision remain sensible. Mark `done` only when these checks pass.

After the reference character, build a batch of 3–4 and correct shared-system mistakes. Then complete the roster in source order or a documented order. Review a consistent contact sheet for scale and style outliers, and recheck all assets together.

## Deliverables and gates

Maintain a registry rather than scattering per-character branches. Provide per-character editable source, export, representative renders, spec/status entry, and in-engine sandbox entry. Keep thumbnails and contact sheets at fixed camera/lighting settings. Automate repeatable exports, captures, and checks when the project warrants it.

Before claiming final completion, verify the complete roster count, exports/imports, required nodes and animations, previous/next wraparound, movement, collision, visible materials, ground contact, and gameplay-camera readability. Test the lowest target platform or state clearly when it is untested. Distinguish first-pass playable assets from approved shipping art.

## References

- [Validation script](scripts/validate_character_specs.py): check the spec handoff before building.
- [Godot example](references/godot-example.md): the successful arena-game-v1 implementation and its remaining quality gates.
