# Asset integration report — MICRO WORLD: LIVING

Every claim here is checkable: `python3 tools/check_assets.py` (268 assertions, run in CI) plus
`.ci/last-run/showcase.log`.

## 1. What was searched for

The brief named these sources. Each was checked for existence *and* licence before anything was
downloaded:

| Requested source | Outcome |
| --- | --- |
| `gobkit-free-assets` | Found at `Ariescar/gobkit-free-assets`; repository licence reports `NOASSERTION` and there is no project-level licence file, so **rejected** — replaced by KayKit (CC0) |
| `CC0Tree` | No reachable repository under that name; tree models instead come from the KayKit Dungeon/City packs and procedural meshes |
| `kit-cidade-lowpoly` | `Kenney`-style low-poly city kit is not published as a GitHub repository; the equivalent CC0 content is **KayKit City Builder Bits**, downloaded |
| `KenneyNL` | No such GitHub organisation. Kenney's audio is used via the CC0 Godot port `Boyquotes/kenney-rpg-audio-for-godot` |
| `Quaternius` | Not reachable from this environment; models replaced with KayKit Adventurers/Skeletons (CC0, and better: they share a skeleton) |
| `boujie_water_shader` | Water is a faceted `SphereMesh` with a transparent `StandardMaterial3D` written in this repo (`world` module), not a third-party shader |

Nothing with an unclear licence was used. Details and hashes: `ASSET_LICENSES.md`.

## 2. What was downloaded

**79 files, 35.5 MB**, pinned to specific commits by `tools/fetch_assets.py` and hashed into
`assets/vendor/ASSET_MANIFEST.json`:

| Category | Files | Content |
| --- | --- | --- |
| Adventurers | 21 | 4 rigged characters (Knight, Mage, Rogue, Barbarian) + 6 weapon meshes + textures + licence |
| Skeletons | 5 | 4 rigged enemies (Minion, Warrior, Mage, Rogue) + licence |
| Dungeon Remastered | 21 | 24 modular pieces: walls, floors, pillars, stairs, doors, chests, torches, barrels, crates, banner |
| City Builder Bits | 16 | 7 buildings + walls, awnings, signposts |
| Kenney RPG Audio | 16 | footsteps ×4, knife slices ×2, coin pickups ×2, door open/close, cloth, metal clicks, book flip, draw knife |

`.fbx` twins shipped in the KayKit packs were deliberately not vendored: the pipeline imports
`.glb`/`.gltf` only, which keeps import fast and the repository small.

## 3. What was imported

`godot --headless --path . --import` converts each GLB/glTF into a Godot scene with an
`AnimationPlayer` and a `Skeleton3D`. CI fails the build if that import emits errors
(`verify.yml` → "Fail on script/import errors": zero `SCRIPT ERROR` lines).

Static verification (before the engine even starts) asserts per character:

- valid GLB 2.0 container with correct chunk lengths,
- a `skins` array (genuinely rigged, not a static mesh),
- `hand.r` and `hand.l` bones present (weapon sockets),
- all **11 gameplay clips** the game drives are present:
  `Idle`, `Walking_A`, `Running_A`, `1H_Melee_Attack_Slice_Horizontal`, `2H_Melee_Attack_Chop`,
  `Dodge_Forward`, `Hit_A`, `Death_A`, `Interact`, `Spellcast_Shoot`, `Jump_Start`.

## 4. How each asset is actually used

This is the part that separates "imported" from "integrated" — nothing below is a showcase-only use.

| Asset | Used by | Behaviour |
| --- | --- | --- |
| `Knight.glb` | Player | Third-person avatar; 20-clip state machine (idle/run/dodge/attack/spell/hit/death/interact) driven by `character_animator.gd` |
| `Mage.glb`, `Rogue.glb`, `Barbarian.glb` | Villagers, player variants, showcase | `npc_actor.gd` dresses Havenbrook's 3 villagers from `AssetCatalog.NPC_*`; all four bodies are stepped in `AssetShowcase` and covered by `tools/check_assets.py`; the save stores the player's chosen body |
| `Skeleton_{Minion,Warrior,Mage,Rogue}.glb` | all 10 monster archetypes | 4 rigged bodies re-scaled per archetype (0.55→1.75) with locomotion/attack/death clips; the Bone Warden is `Skeleton_Warrior` at 1.75× with phase-tinted material |
| `sword_1handed.gltf` | Iron Sword, Bone Blade, Warden Greatsword (2H) | Socketed to `hand.r` via `BoneAttachment3D`, verified by a scene assertion |
| `staff.gltf` | Frost Staff, Ember Staff | Socketed; visual matches the equipped item id |
| `dagger.gltf`, `axe_1handed.gltf`, `shield_round.gltf` | Inventory items + offhand | Dagger/axe socket to `hand.r`, shield to `hand.l` |
| Dungeon walls/floors/pillars/stairs | Barrow of the Bone Warden | 3 rooms built on a 4 m tile grid with the modular kit |
| Dungeon chest/barrel/crate/banner/torch | Dungeon + Havenbrook | Chests are interactable and persist `opened_chests`; torches carry real `OmniLight3D`s (radius 9 m) |
| City buildings (7) | Havenbrook | Registrar hall, forge, shop and four houses placed on the village ring |
| Footsteps ×4 | Player + monsters | Cycled by distance travelled, pitch-varied per surface |
| Knife slices ×2 | Melee impacts | Played on hit; volume scaled by damage |
| Coins ×2 | Chests, shop, quest rewards | Played with the gold popup |
| Doors, cloth, metal, book flip | Panels, dodge, interact | UI and interaction feedback |
| `Kenney` audio | `audio_manager.gd` | Pooled single player per category, respects the "Sound effects" setting |

## 5. Showcase scene

`scenes/AssetShowcase.tscn` builds a verification stage: every character is instantiated with its
`AnimationPlayer` stepping, every weapon and prop is placed on a grid, and the scene prints a verdict.

```
ASSET SHOWCASE — 34 loaded, 0 failed
SHOWCASE_RESULT: PASS
```

CI runs it with `-- --verify`, and the workflow **fails** if the line is missing or not `PASS`
(this was tightened after an earlier run silently produced no verdict).

## 6. Verified failure modes (fixed, kept as tests)

| Problem | Symptom | Fix |
| --- | --- | --- |
| glTF bones are not scene nodes | Weapons could never attach (`_weapon_node == null`) | `BoneAttachment3D` socket, with a plain-node fallback for non-skinned props |
| KayKit bounds include non-T-pose keyframes | Characters appeared to be the wrong size | Explicit `model_scale` multipliers instead of measuring bounds |
| Untyped arrays on typed resources | `Invalid assignment of property 'entries'` at runtime | `.assign()` on `Array[Dictionary]` resources |
| Missing asset silently degrading | Placeholder capsule instead of a model | `asset_catalog.gd` `REQUIRED_PATHS` + static verifier fails the build |

## 7. Not integrated (and why)

- **Music**: no CC0 soundtrack was verified in the reachable sources, and a placeholder loop would be
  a non-functional decoration.
- **Animations beyond the two packs**: quaternius/gobkit rigs were rejected, so all animation is
  KayKit's shared humanoid set. Anything needing a quadruped or flying rig is unrepresented.
- **Sky/HDRI**: the sky is a procedural `PhysicalSkyMaterial`; no HDRI was downloadable.
- **Water shader**: written in-repo, since the requested third-party shader could not be reached.
