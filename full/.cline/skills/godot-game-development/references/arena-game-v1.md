# Godot 4.7 example

`arena-game-v1/project.godot` selects Godot 4.7 and the mobile renderer. Its `docs/ASSETS.md` sets per-project art budgets. `game/greybox_pawn.gd` owns the playable pawn; `game/characters/character_sandbox.tscn` exercises visual model swaps through that pawn. `tools/test_character_models.tscn`, `test_character_exports.tscn`, and `test_character_sandbox.tscn` cover structure and behavior. `tools/capture_character_roster.tscn` renders real frames for visual inspection.

The transferable pattern is to test both Godot import/runtime behavior and what the player sees. A headless pass cannot prove materials, lighting, camera readability, or feel. This project's 60 FPS Android aim and triangle budgets are local targets, not defaults for every Godot game.
