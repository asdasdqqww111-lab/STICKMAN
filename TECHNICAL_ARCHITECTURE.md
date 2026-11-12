# Technical architecture — MICRO WORLD: LIVING

## 1. Shape of the codebase

```
project.godot                 Godot 4.7, GL Compatibility, 1280×720, landscape, 30 Hz physics
scenes/
  App.tscn                    main menu router (Launch/Continue/Settings/Quit)
  Game.tscn                   the playable world (single node running game_world.gd)
  AssetShowcase.tscn          verification stage for every vendored asset
scripts/
  core/    asset_catalog  character_animator  player_state  save_game  quest_log
           rank_rules  audio_manager  game_settings
  data/    item_data  enemy_data  quest_data  spell_data  loot_table
           item_database  monster_definitions  spell_database  quest_database
  planet/  sphere_math  terrain  planet_mesh  planet_regions
  world/   world_clock  world_simulation  world_builder  dungeon_builder
           npc_actor  resource_node  interactable
  player/  player_controller  camera_rig
  combat/  enemy_actor  combat_system  vfx
  ui/      ui_theme  main_menu  hud  touch_controls  game_panels
  game/    app  game_world
  debug/   asset_showcase
tests/     run_tests + 6 suites + benchmark
tools/     fetch_assets.py  check_assets.py  inspect_glb.py  glb_bounds.py  ci/
```

Roughly **7,800 lines** of GDScript in `scripts/`, **1,100** in `tests/`. There is no autoload:
every system is explicitly constructed and injected by `game_world.gd`, which keeps ownership
readable and makes tests able to build a world without the engine's global state.

## 2. Why a spherical planet instead of a heightmap

A `HeightMapShape`/`GridMap` world is flat by construction. Here the *reference frame itself*
rotates: `SphereMath` maps a unit **direction** to a world position and a local tangent frame.

- Planet radius: **250 m** (`SphereMath.RADIUS`).
- Position = `direction * (RADIUS + elevation(direction))`.
- Gravity = `-direction`, i.e. always toward the centre.
- Movement is **arc-length** on the sphere, so walking speed is constant in metres regardless of
  where you are, and a step never leaves the surface.
- Collision is analytic: `ground_point()` clamps a position back onto the terrain radius. No
  `CharacterBody3D` is used for the player, which removes the need for a planet-sized collision mesh.

Terrain is a deterministic value-noise FBM (`terrain.gd`), sampled on demand, so it exists
everywhere without being stored. Biomes come from elevation + moisture bands.

## 3. Mesh generation

`planet_mesh.gd` builds a **cube-sphere**: for each of 6 faces, a `(n+1)²` grid of directions is
projected onto the sphere, each vertex displaced by `elevation()`, coloured by biome, and emitted as
one `ArrayMesh` surface. At the default 16×16/face that is 3,072 triangles in 6 draw calls, plus a
faceted ocean shell. Faces are generated on a worker thread; the main thread only uploads.

`planet_regions.gd` subdivides each face into `SIZE = 12` regions per edge → **864 regions** with
canonical ids like `"pz:3:5"`. Regions are the unit of:
- prop streaming visibility,
- monster sleep/wake decisions,
- **save-game discovery progress** (v4 format).

## 4. Data-driven content

Everything content-like is data, not code:

| Resource | Producer | Consumers |
| --- | --- | --- |
| `ItemData` | `item_database` (24 items, 8 recipes) | inventory, equipment, shop, crafting, loot |
| `EnemyData` | `monster_definitions` (10 archetypes) | spawning, AI, loot, bestiary |
| `QuestData` | `quest_database` (15 quests) | quest log, HUD tracker, rewards |
| `SpellData` | `spell_database` (6 spells, 3 schools) | casting, cooldowns, damage |
| `LootTable` | built per archetype/chest in `game_world` | weighted rolls with guaranteed drops |

Adding an item is a dictionary entry plus (optionally) a model path — no code changes. Tests assert
that every quest reward, recipe input, loot entry and shop listing refers to a real item id, so a
typo becomes a red build rather than a runtime crash.

## 5. Spherical player and camera

`player_controller.gd` keeps an orthonormal frame `(up = direction, forward, right)` and moves along
great circles. `camera_rig.gd` places the camera along the tangent plane behind the player, then
pushes it outside the planet radius so it never ends up underground, and supports an orbit/look
input, zoom, and a "planet overview" mode.

## 6. Animation contract

`character_animator.gd` does **not** hard-code clip names. `AssetCatalog.ANIM` lists candidate names
per gameplay state (e.g. `run → ["Running_A", "Run", "Walk"]`), resolved once against the imported
library. This is why the same animator drives Knights and Skeletons, whose 76/95 clip sets overlap
but are not identical. Weapons attach via `BoneAttachment3D` on `hand.r`/`hand.l`.

## 7. Combat model

`combat_system.gd` resolves melee as a cone sweep: candidates within reach and inside the facing arc,
sorted by distance, with critical hits and armour mitigation. `enemy_actor.gd` is a small state
machine (idle → patrol → chase → attack → return) with leash limits and region-aware sleep. Damage
numbers, slash arcs and boss phase bursts are `vfx.gd` primitives. The boss changes phase at 70 % and
35 % health, applying damage multipliers and a visual tint.

## 8. Save format (v4)

`save_game.gd` writes JSON to `user://`, atomically:

1. Serialise the `PlayerState` document (level, XP, gold, skill points, ranks, quests, inventory,
   equipment, spells, region discoveries, opened chests, gathered nodes, lit shrines, clock, player
   direction, settings-relevant fields).
2. Write `save.tmp`, flush, then `rename` over `save.json` (atomic on POSIX and on Android's
   `user://` — verified by the "atomic write leaves no partial file" test).
3. Rotate the previous generation to `save.bak` **after** validating it.
4. On load: validate, fall back to `save.bak`, and copy the unreadable file to `save.corrupt`.

Version handling: `save.json` carries `"version": 4`. A v1 protoype document migrates through
v1→v2→v3→v4 (legacy stage flags become quests/items; the legacy 64×64 cell grid collapses to region
ids), each step tested. A file with a *newer* version than the build refuses to be overwritten and is
left untouched.

## 9. Android specifics

- Landscape, immersive, safe-area inset aware (`touch_controls.gd` reads
  `DisplayServer.get_display_safe_area()`).
- Virtual stick + five action buttons; panels are bottom sheets; all touch targets ≥ 44 dp.
- Quality presets scale `planet_resolution`, render scale, shadows and monster counts.
- Export preset: `use_gradle_build=false` (no Gradle/NDK needed), arm64-v8a + armeabi-v7a + x86_64,
  `export_filter="all_resources"` with `tests/`, `tools/`, `.ci/` excluded so the APK carries only
  the game.

## 10. CI/CD

| Workflow | Trigger | Job |
| --- | --- | --- |
| `verify.yml` | every push | install pinned Godot → static asset verification (268 checks) → import → fail on script errors → 6 test suites → benchmark → showcase `--verify` → publish logs to `.ci/last-run/` |
| `android-build.yml` | every push | Godot + export templates + JDK 17 + Android SDK 35 → debug keystore → export APK → inspect + verify contents → checksum → artifact + GitHub Release `android-debug-<run>` → publish `.ci/android/` |

Both workflows commit their logs back to the branch (rebase-retried) so evidence lives beside the
code instead of in an unreachable CI console.
