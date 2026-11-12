# MICRO WORLD: LIVING

A Godot 4 GDScript **early playable foundation**, not the requested finished RPG or MVP. The repository originally contained only `# STICKMAN`. The long-term goal is an offline, spherical fantasy world on Android; the present slice is deliberately much smaller.

## Current slice

A radius-250-unit spherical surface with tangent movement and radial alignment; a follow camera and planet overview; up to nine streamed deterministic visual prop cells using a six-face cube partition; a discovery-only world map and activated fast-travel points; an outpost with a guild registrar; eight simple slimes with chase/return behavior; two guild contracts; F–D promotions with multiple requirements; eight collectible herbs; potion crafting and healing; one forgeable iron sword that increases melee damage; XP, leveling, gold, one mana-limited arcane attack, exploration discovery, day/night lighting, and versioned local saves with a previous-generation backup. The surface is smooth, movement is analytically constrained, and neither the terrain nor attacks use physics collision/hitboxes. The house models are exterior landmarks, not enterable buildings. No online services are required at runtime.

## Run

1. Install **Godot 4.7.2 stable**, open `project.godot` and let it import the GLB files.
2. Run the main scene (`F6`/`F5` as appropriate). On desktop use **WASD/arrow keys** to move, **E** to talk near the gold registrar, **Space** to strike, **Q** to cast, **M** for the planet overview, **Tab** for the discovery map, **C** to craft a potion, **H** to use it, **F** to forge a sword, **F5** to save. On-screen directional and action buttons provide initial touch controls. The camera faces north; movement is north/east relative to the sphere.
3. Talk to the registrar, defeat three slimes and return to claim the reward. Talk again for the herb contract: approach purple herbs and press E. Gathered counts are credited even before accepting the contract. After both contracts, talk to the registrar for rank requirements; additional kills and exploration allow promotion to E and D. Move toward the far side of the houses to find the slimes. Craft a potion for two herbs, or forge a sword for two herbs and 12 gold; use a potion when injured. Talk to the registrar to activate the outpost travel point; approach and interact with the two golden shrine markers to activate them. Open the map and select an activated destination. Travel is blocked when an enemy is near either end; the world continues while the map is open. Saves go to Godot's `user://` directory, independent of this repository.

For tests after editor import, in a **fresh isolated user directory** to avoid loading an existing game:

```sh
mkdir -p /tmp/micro-world-test-home
HOME=/tmp/micro-world-test-home godot --headless --path . --editor --quit
HOME=/tmp/micro-world-test-home godot --headless --path . --script res://tests/test_core.gd
HOME=/tmp/micro-world-test-home godot --headless --path . --script res://tests/test_scene.gd
HOME=/tmp/micro-world-test-home godot --headless --path . --script res://tests/test_world.gd
```

See `TEST_REPORT.md` for tests actually executed here, and `ANDROID_BUILD_GUIDE.md` for prerequisites. Project source and third-party license notices are kept in the repository; imported `.godot` caches and APKs are not.

## Documents

`GAME_DESIGN_DOCUMENT.md`, `WORLD_LORE.md`, `TECHNICAL_ARCHITECTURE.md`, `ASSET_LICENSES.md`, `ASSET_INTEGRATION_REPORT.md`, `TEST_REPORT.md`, `PERFORMANCE_REPORT.md`, `ANDROID_BUILD_GUIDE.md`, `ROADMAP.md`, `KNOWN_ISSUES.md`, `documentation/ENVIRONMENT_REPORT.md`.
