# Godot reference implementation

`arena-game-v1` built 18 food characters from a frontal concept sheet using deterministic Godot geometry:

- `docs/research/character_concepts/model_map.json` and `docs/CHARACTER_MODEL_PLAN.md` hold the image interpretation and 3D recipes.
- `game/characters/character_model_factory.gd` owns roster order and shared `Body`, `Face`, `LeftArm`, `RightArm`, `LeftFoot`, `RightFoot`, and `SlotAccent` roots. `character_shapes_{top,middle,bottom}.gd` builds per-character bodies; `character_parts.gd` supplies primitives.
- `tools/export_character_models.gd` writes portable GLBs; `character_visual.gd` animates rigid pivots for seven states. These GLBs do not contain a skinned skeleton or baked clips.
- `character_sandbox.tscn` uses a real pawn, movement, previous/next wraparound and state previews. `capture_character_roster.tscn` produces consistent game renders. `test_character_models.tscn`, `test_character_exports.tscn`, and `test_character_sandbox.tscn` check shape, import, and play behavior.

The 18 exports are first-pass playable interpretations. The source lacks turnarounds; unseen geometry was authored. Final art approval, eight-player readability and target Android performance remain separate gates. Reuse the workflow, not the food roster, fixed dimensions, or Godot-specific code in unrelated projects.
