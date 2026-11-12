# Current project status — MICRO WORLD: LIVING

**Branch:** `arena/9ad98e08-stickman` · **Engine:** Godot 4.7.2-stable · **Target:** Android (landscape) + desktop

Legend — **Tested** = covered by an automated check that runs in CI · **Implemented** = works but not
asserted · **Partial** = works with declared gaps · **Broken** · **Not Implemented**.

Every row names the file that provides the evidence. Nothing here is aspirational.

---

## Core engine & planet

| System | Status | Evidence | Gaps |
| --- | --- | --- | --- |
| Cube-sphere planet mesh | **Tested** | `scripts/planet/planet_mesh.gd`, `tests/test_planet.gd::_test_mesh_generation` (adjacency, index range, vertex radii) | Single LOD per face; no displacement shader — geometry is CPU-generated once at load |
| Spherical gravity / movement | **Tested** | `scripts/planet/sphere_math.gd`, `move()` arc-length tests, live-scene movement test | Analytic only: no `CharacterBody3D`, so no physics-body interactions |
| Deterministic terrain | **Tested** | `scripts/planet/terrain.gd` FBM, determinism + biome coverage tests | No marching-cubes caves; the barrow is a separate underground room |
| Biomes | **Tested** | 7 biomes (`OCEAN…RUINS`), ≥3 biomes asserted on a 240-sample scan | No snow-line weather, no biome-specific props beyond colour |
| Region grid (864 regions) | **Tested** | `scripts/planet/planet_regions.gd`, round-trip + 6-face coverage tests | `SIZE = 12` is coarse (≈33 m per region) |
| Region streaming | **Implemented** | `scripts/world/world_simulation.gd` — props culled by region, 2-region radius | Prop *instances* stay in memory, only visibility toggles |
| World streaming of terrain | **Partial** | Whole planet mesh is generated at load (6 faces) | No chunked terrain streaming yet — see KNOWN_ISSUES #1 |
| Simulation LOD | **Tested** | `world_simulation.gd::_apply_monster_lod`, 45 m radius, max 24 active | NPC LOD not distance-based yet |
| Day/night cycle | **Implemented** | `scripts/world/world_clock.gd`, 12-minute day, 4 phases, sun colour curve | No weather |
| Ocean | **Implemented** | Faceted transparent SphereMesh at `WATER_LEVEL` | No shoreline waves, no swimming |

## Player & camera

| System | Status | Evidence | Gaps |
| --- | --- | --- | --- |
| Character model | **Tested** | KayKit `Knight.glb` (76 clips) attached in `player_controller.gd`; scene test asserts animator + `run`/`attack_light`/`death` clips | One playable body (Mage/Rogue GLBs vendored, selectable only in code) |
| Walk / run / sprint | **Tested** | `_move()` arc-length test (0.0 m failure was fixed → movement asserted > 1 m) | No slope-speed penalty |
| Jump | **Implemented** | `jump()` + analytic gravity | No air control |
| Dodge (i-frames) | **Implemented** | `dodge()`, 0.35 s invulnerability, stamina cost | No directional dodge animation blending |
| Third-person camera | **Implemented** | `scripts/player/camera_rig.gd`, orbit/pitch/zoom + overview mode; camera kept outside the planet (asserted) | No collision push-in against dungeon walls |
| Health / mana / stamina | **Tested** | `player_state.gd` derived stats + regeneration | Death by falling not implemented (no fall damage) |
| Equipment visuals | **Tested** | Weapon socketed onto `hand.r`; scene test asserts `_weapon_node != null` after equipping | Armour is stat-only (no visual swap) |

## Combat & content

| System | Status | Evidence | Gaps |
| --- | --- | --- | --- |
| Light / heavy melee | **Tested** | `combat_system.gd::resolve_melee`, cone sweep, crits | Hit detection is distance+cone, not physics hitboxes |
| Spells | **Tested** | 6 spells / 3 schools, cast tests | Projectiles are VFX-only; damage resolves instantly |
| Enemy AI | **Tested** | `enemy_actor.gd` 6 states, leash, aggro; monster data tests | No ranged kiting, no group tactics |
| Boss with phases | **Implemented** | `boss_phase` 1→3 at 70 %/35 % health, damage multipliers, phase VFX | Phases change stats only (no new attack patterns) |
| Monster roster | **Tested** | 10 archetypes in `monster_definitions.gd`, all models verified | 4 visual models reused across 10 archetypes |
| Peaceful wildlife | **Partial** | `MonsterDefinitions.PASSIVE` declared | Not spawned in the world yet |
| VFX | **Implemented** | `combat/vfx.gd` slash, bolt, impact, damage numbers, boss burst | Primitive meshes, no particle systems |
| Audio | **Implemented** | `core/audio_manager.gd` + 15 CC0 clips (footsteps, hits, coins, doors) | No music, no positional ambience |

## Progression, economy, world

| System | Status | Evidence | Gaps |
| --- | --- | --- | --- |
| XP & levels | **Tested** | Curve to level 60, level-up tests | No level cap display |
| Skill points | **Tested** | 3 skills × 5 ranks, derived stats asserted | No skill trees |
| Guild ranks | **Tested** | `rank_rules.gd`, F→E→D tuned + requirements tested, promotion through `PlayerState.try_promote` | C declared but untuned; B/A/S not implemented |
| Quests | **Tested** | 15 quests, uniqueness + prerequisite-cycle checks, full accept→progress→turn-in flow | Turn-in happens only at the registrar; no quest markers |
| Inventory | **Tested** | 24 items, stacking, overflow rows, use/sell | No drag & drop, no sorting |
| Equipment | **Tested** | 3 slots, two-handed clears offhand, stat deltas asserted | No durability |
| Crafting | **Tested** | 8 recipes, rank gating, cost/material consumption asserted | Forge UI is a flat list |
| Economy / shop | **Implemented** | Buy/sell, 1.6× markup, 0.45× sell | No dynamic prices |
| Loot tables | **Tested** | Weighted rolls, guaranteed drops, determinism | — |
| Chests | **Tested** | 4 chests, opened-state persisted; live-scene gold assertion | — |
| Resource nodes | **Tested** | 24 nodes, harvest → inventory → `gathered` persistence | Regrowth timer not scheduled |
| NPCs & schedules | **Implemented** | 3 villagers with 3-slot daily schedules, greetings by hour | Villagers do not hold conversations beyond a greeting |
| Properties / building | **Partial** | `PlayerState.buy_property` exists and is saved | No build UI or world placement |
| Dungeon | **Partial** | `dungeon_builder.gd` builds 3 rooms from dungeon tiles + boss hall | Teleports the player to a point; no interior collision geometry |
| Fast travel | **Tested** | 5 shrines, unlock + travel asserted in the live scene | Travel menu lists only lit shrines (by design) |

## Save system

| System | Status | Evidence | Gaps |
| --- | --- | --- | --- |
| Versioned JSON save (v4) | **Tested** | `core/save_game.gd`, round-trip test over 18 fields | — |
| Atomic write + rotation | **Tested** | temp → rename, backup holds previous generation (asserted by corrupting the primary) | — |
| Corruption recovery | **Tested** | corrupt primary loads from backup; copy kept as `.corrupt` | — |
| Newer-version protection | **Tested** | refuses to overwrite a v9 file, file preserved | — |
| Migration v1→v4 | **Tested** | prototype stage flags → quests/inventory/equipment; cube-cell → region ids | v5 migration path not yet written |
| Autosave | **Implemented** | 45 s timer + on pause/close/focus-loss | No manual save-slot selection |
| Save validation | **Tested** | 8 rejection cases (level, rank, items, XP, direction…) | — |

## UI / Android

| System | Status | Evidence | Gaps |
| --- | --- | --- | --- |
| Main menu | **Tested** | Continue disabled without a save, enabled with one (asserted) | No language selection |
| HUD | **Implemented** | Vitals, XP, rank, gold, clock, region, quest tracker, target frame, interaction prompt | No minimap |
| Panels | **Tested** | All 11 panels open without error in the scene test | Inventory list is vertical only |
| Virtual stick + buttons | **Implemented** | `ui/touch_controls.gd`, safe-area aware | Multi-touch stick/look verified only by code review, not on a device |
| Android export preset | **Implemented** | `export_presets.cfg`, `com.microworld.living`, landscape, immersive | Min SDK left at the template default (Android 6+); Android 9 specifically is not pinned |
| Debug APK | **Tested (build + content)** | CI job 43255276245, 101,212,863 bytes, SHA-256 `d43bfcf8…58d9c8`, manifest + arm64/armv7/x86_64 libs verified | Not installed on a physical device from this environment |
| Release APK / AAB | **Not Implemented** | — | Requires a signing keystore, which must not live in Git |

## Tests

| Suite | Assertions | Result |
| --- | --- | --- |
| `test_planet.gd` | 65 | pass |
| `test_player.gd` | 96 | pass |
| `test_quests.gd` | 236 | pass |
| `test_save.gd` | 52 | pass |
| `test_combat.gd` | 185 | pass |
| `test_scene.gd` (live scene + scripted play session) | 74+ | pass |
| `tools/check_assets.py` (static) | 268 | pass |

See [`TEST_REPORT.md`](TEST_REPORT.md) for commands and raw log excerpts.
