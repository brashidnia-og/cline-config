# Arena-game-v1 example

In `arena-game-v1`, `game/characters/character_model_factory.gd` centralizes character IDs and display names; `character_shapes_*.gd` owns distinctive bodies, and `character_visual.gd` supplies the shared motion vocabulary. `game/greybox_pawn.gd` keeps the gameplay collision and controls while the visual model changes. This is useful reuse across 18 actual variants, with no need for a general-purpose asset framework.

The project also separates game and platform ownership in `docs/DECISIONS.md`: the game owns match/combat, and the platform layer owns input/join/graphics/session helpers. Tests and `tools/bot_eval.py` measure behavior at meaningful boundaries. Those are project choices, not universal file layouts.
