# Test report — MICRO WORLD: LIVING

All results below are copied from CI logs committed back into this repository under
`.ci/last-run/` and `.ci/android/`, so they can be audited without trusting this document.

- Reproducing: `bash tools/ci/install_godot.sh && bash tools/ci/run_tests.sh`
- CI workflow: [`.github/workflows/verify.yml`](.github/workflows/verify.yml)
- Engine used in every run: **Godot 4.7.2-stable** (downloaded and pinned by `tools/ci/install_godot.sh`)

---

## 1. Static asset verification — `python3 tools/check_assets.py`

Run before the engine is even started, so an asset problem can never masquerade as a code problem.

| Group | Assertions |
| --- | --- |
| Manifest integrity | 79 vendored files present and SHA-256 matching the pinned upstream commit |
| Catalog coverage | 56 `res://assets/...` paths in `scripts/core/asset_catalog.gd` exist on disk |
| Rigged characters (8 GLBs) | valid GLB container, skinned, `hand.r`/`hand.l` present, all 11 gameplay clips resolved |
| Weapons | 6 separate weapon meshes with geometry |
| Audio | 16 Ogg Vorbis files with valid `OggS` headers |

**Result: 268 checks, 0 failures** (`all asset checks passed`).

## 2. Headless GDScript suites — `godot --headless --script tests/run_tests.gd`

| Suite | Checks | Failures |
| --- | --- | --- |
| `tests/test_planet.gd` — cube-sphere maths, terrain determinism, biomes, regions | 65 | 0 |
| `tests/test_player.gd` — stats, XP, ranks, inventory, equipment, crafting, death | 96 | 0 |
| `tests/test_quests.gd` — quest graph, acceptance rules, rewards, shops, loot | 236 | 0 |
| `tests/test_save.gd` — round-trip, atomic write, backup, corruption, migration | 52 | 0 |
| `tests/test_combat.gd` — damage formulae, AI, boss phases, spells, catalog | 185 | 0 |
| `tests/test_scene.gd` — boots `App.tscn` and `Game.tscn`, then plays a scripted session | 84 | 0 |
| **Total** | **718** | **0** |

Plus, per run:

| Extra gate | Result |
| --- | --- |
| `tools/check_assets.py` (static asset verification) | 268 checks, 0 failures |
| `tests/benchmark.gd` (world-generation performance) | 4 measurements printed, no errors |
| `AssetShowcase.tscn -- --verify` | `34 loaded, 0 failed`, `SHOWCASE_RESULT: PASS` |

`test_scene.gd` is not a smoke test. It instantiates the real main scene, opens the real game
scene, and then performs an actual play session inside it:

1. asserts the KayKit rig is present and that `run` / `attack_light` / `death` clips resolved out of
   the imported GLB animation library;
2. moves the player across the planet surface and asserts real displacement;
3. swings light and heavy attacks, casts a spell, takes damage, dies and respawns;
4. kills a monster with real damage and asserts the `defeated` signal plus loot;
5. opens a chest and asserts the gold reward and the persisted `opened_chests` flag;
6. accepts a quest, turns in a contract, records completion;
7. harvests a resource node, crafts a potion, equips a sword and asserts the weapon is socketed to
   the `hand.r` bone through a `BoneAttachment3D`;
8. saves, reloads and compares hero name, materials, equipment and metadata;
9. opens every UI panel and closes it.

## 3. Asset showcase — `godot --headless scenes/AssetShowcase.tscn -- --verify`

```
ASSET SHOWCASE — 34 loaded, 0 failed
SHOWCASE_RESULT: PASS
```

34 real third-party assets are instantiated as 3D Nodes (8 rigged characters, 6 weapons, 24 dungeon
props, 7 city buildings + audio), each laid out on a verification stage with its animation player
stepping, so a broken import fails the build.

## 4. Android build & APK verification

Workflow: [`.github/workflows/android-build.yml`](.github/workflows/android-build.yml).

| Step | Result |
| --- | --- |
| Install Godot 4.7.2 + Android export templates | success |
| Install JDK 17 / Android SDK platform 35 + build-tools 35 | success |
| Create throwaway debug keystore | success |
| `--import` project | success |
| `--export-debug "Android Debug" build/microworld-living-debug.apk` | success |
| Inspect APK (zip listing + binary manifest strings) | success |
| Verify APK contents | success (payload, `lib/arm64-v8a/libgodot_android.so`, package string in the binary manifest) |
| Publish artifact + Release | success |

Verified APK facts (run `43255276245`):

| Property | Value |
| --- | --- |
| Size | 101,212,863 bytes (96.5 MB) |
| SHA-256 | `d43bfcf8afd54154c92346a315f8d16bdba803cefaaaa3742066fa98c058d9c8` |
| Package | `com.microworld.living` (found in the binary `AndroidManifest.xml`) |
| Native libs | `arm64-v8a`, `armeabi-v7a`, `x86_64` `libgodot_android.so` |
| Payload | Godot PCK embedded in the APK assets |
| Release tag | `android-debug-6` |
| Artifact name | `microworld-living-debug-apk` |

## 5. What is *not* covered by automated tests

Stated plainly, because the acceptance criteria demand honesty:

| Item | Why |
| --- | --- |
| Installation and play on a physical Android device | No device or emulator is available in this environment. The APK was built and its contents verified; it was **not** run on hardware here. |
| Frame rate on Android | Same reason — no device. See `PERFORMANCE_REPORT.md`, which labels every number as measured-on-runner or unmeasured. |
| Touch feel (thumb reach, stick dead-zone comfort) | Requires a device. The layout is safe-area aware and sized for thumbs, but subjective comfort is untested. |
| Long play sessions / memory leaks | Suites run in seconds; no soak test exists yet. |
| Desktop manual playthrough | Only the scripted session above; a human playthrough has not been recorded. |

## 6. Regression history in this branch

Each of these was a real failure found by CI and fixed, not a cosmetic edit:

| Failure | Root cause | Fix |
| --- | --- | --- |
| `scene: 74 checks, 6 failures` | Typed-array assignment on `Array[Dictionary]` resources; NPC schedule literal; combat used before construction | `.assign()` for resource arrays, untyped schedule parameter, null-guarded combat registration |
| `player can die` failed | Passive mana/health regeneration resurrected the player after death | `regenerate()` returns early when dead + regression assertion |
| `equipped weapon is attached to the hand bone` failed | glTF bones live inside `Skeleton3D`, so a bone is not a `Node3D` that can be parented to | weapon socketed via `BoneAttachment3D` with a plain-node fallback |
| `player moves forward on the planet (0.0 m)` failed | The test drove input, which is intentionally ignored while a panel is open | Test drives the controller path directly |
| Android "Verify APK contents" failed | Assertions guessed the wrong payload/manifest encoding | Verified against the real zip listing and binary manifest |
| CI logs never landed | The verify and android workflows raced on the same branch | Both retry `git pull --rebase` before publishing |
