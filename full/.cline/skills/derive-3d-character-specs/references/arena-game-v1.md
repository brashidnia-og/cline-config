# Arena game example

Source: `arena-game-v1/docs/research/character_concepts/reference.png`, a 640×406 mostly frontal sheet with 18 labeled food characters. The project recorded source order and body/part descriptions in `model_map.json`, and fuller recipes in `docs/CHARACTER_MODEL_PLAN.md`.

Examples of the translation step:

- Avocado Vock: observed broad-bottom green pear, light front patch and pit; interpreted plain green back and finite body depth; recipe is an extruded pear profile plus separate front patch and pit.
- Milk Mildred: observed carton silhouette and blue panels; recipe is a beveled box, gable top, and separate color panels; back label is an authored decision.
- Donut Donny: observed open ring, pink icing and sprinkles; recipe uses a torus and distinct icing/sprinkle pieces; preserve the hole from the gameplay camera.

The subsequent build used Godot primitives and extruded profiles, rather than Blender, because Blender was unavailable. The skill should specify *what* to build and mark uncertainty; the builder chooses the available reproducible modeling tool.
