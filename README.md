# MICRO WORLD: LIVING

A **third-person open-world RPG on a living, streamed planet**, built with Godot 4.7 and GDScript,
targeting Android first.

> **Status: playable vertical slice + installable Android APK.**
> Real spherical planet, real CC0 art, real combat, quests, crafting, saving and a signed
> debug APK produced by CI. Read [`CURRENT_PROJECT_STATUS.md`](CURRENT_PROJECT_STATUS.md) for the
> honest per-system breakdown and [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) for the gaps.

---

## Download the Android build

| Artifact | Where |
| --- | --- |
| Debug APK (96.5 MB, universal: arm64-v8a + armeabi-v7a + x86_64) | [Latest GitHub Release](../../releases/latest) |
| APK checksum | `apk.sha256` attached to the same release |
| CI workflow that builds it | [`.github/workflows/android-build.yml`](.github/workflows/android-build.yml) |

Install on a device:

```bash
adb install -r MICRO-WORLD-LIVING-<run>-debug.apk
```

The APK is a **debug**-signed build (this repository ships no release keystore). See
[`ANDROID_BUILD_GUIDE.md`](ANDROID_BUILD_GUIDE.md) to produce an AAB release build with your own
signing key.

---

## What is actually in the game

| Area | Reality |
| --- | --- |
| Planet | Cube-sphere of radius 250 m, 6 faces × 16×16 quads, deterministic FBM terrain, 7 biomes, faceted ocean shell |
| Streaming | 6×12×12 = 864 streamed regions; props culled by region, monsters switch to simulation LOD beyond 45 m |
| Player | KayKit Knight GLB (76 clips), walk / run / jump / dodge / light + heavy attack / spell cast |
| Camera | Spherical third-person rig with orbit, pitch, zoom and a planet-overview mode |
| Combat | Cone-swept melee with crits, 6 spells in 3 schools, hit reactions, damage numbers, boss phases |
| Monsters | 10 archetypes (9 regular + 1 boss) with idle / patrol / chase / attack / return AI |
| Content | Havenbrook village, 5 shrines, 24 resource nodes, 4 chests, a 3-room dungeon, 15 quests |
| Progression | XP curve to level 60, skill points, guild ranks F→E→D tuned (C declared), crafting, shops |
| Saving | Versioned (v4) JSON, atomic rename, backup rotation, corruption recovery, v1/v2/v3 migration |
| UI | Main menu, HUD, inventory, equipment, quests, map, grimoire, guild, shop, skills, forge, pause, settings |
| Android | Landscape, virtual stick, action buttons, safe-area aware, Low/Medium/High quality presets |

---

## Running from source

```bash
# Godot 4.7.2 (the exact version the project and CI pin)
godot --path . --import          # first import parses every script
godot --path .                   # opens the main menu
godot --path . scenes/Game.tscn  # jump straight into the world
godot --path . scenes/AssetShowcase.tscn   # inspect every vendored 3D asset
```

Desktop controls: **WASD/arrows** move, **mouse drag (right button)** look, **J** light attack,
**K** heavy attack, **Space** jump, **L** dodge, **E** interact, **Q** cast, **Esc** menu.

### Tests

```bash
bash tools/ci/install_godot.sh      # pinned engine (no templates needed)
bash tools/ci/run_tests.sh          # 6 suites, 700+ assertions
```

CI runs the same commands on every push ([`verify.yml`](.github/workflows/verify.yml)) and writes
the raw logs back to `.ci/last-run/` so results are auditable from the repository itself.

---

## Repository layout

```
scripts/
  core/      player_state, save_game, quest_log, rank_rules, audio, animator, settings, asset catalog
  data/      item/enemy/quest/spell Resources + databases (data-driven content)
  planet/    sphere math, terrain, cube-sphere mesh builder, region grid
  world/     world clock, streaming/LOD, builder, dungeon, NPCs, resources, interactables
  player/    player controller, camera rig
  combat/    enemy AI, combat resolution, VFX
  ui/        theme, main menu, HUD, touch controls, panels
  game/      app router + playable world
  debug/     asset showcase
scenes/      App.tscn (menu), Game.tscn (world), AssetShowcase.tscn
tests/       headless GDScript suites
tools/       fetch_assets.py (CC0 pipeline), ci/ (Godot install, tests, APK build)
assets/vendor/  pinned third-party CC0 assets + ASSET_MANIFEST.json
```

Architecture rationale: [`TECHNICAL_ARCHITECTURE.md`](TECHNICAL_ARCHITECTURE.md).

---

## Assets and licences

All shipped third-party art and audio is **CC0** (public domain), fetched at pinned commits by
`tools/fetch_assets.py` and hashed in `assets/vendor/ASSET_MANIFEST.json`:

- **KayKit** by Kay Lousberg — Adventurers, Skeletons, Dungeon Remastered, City Builder Bits
- **Kenney** RPG Audio (Godot port by Boyquotes)

Full attribution, upstream commits and per-file hashes: [`ASSET_LICENSES.md`](ASSET_LICENSES.md)
and [`ASSET_INTEGRATION_REPORT.md`](ASSET_INTEGRATION_REPORT.md).

---

## Documentation

| Document | Contents |
| --- | --- |
| [`CURRENT_PROJECT_STATUS.md`](CURRENT_PROJECT_STATUS.md) | Per-system status with evidence |
| [`GAME_DESIGN_DOCUMENT.md`](GAME_DESIGN_DOCUMENT.md) | Loop, content, progression, Android UX |
| [`WORLD_LORE.md`](WORLD_LORE.md) | World, factions, the Bone Warden |
| [`TECHNICAL_ARCHITECTURE.md`](TECHNICAL_ARCHITECTURE.md) | Module map, data flow, save format |
| [`ENVIRONMENT_AUDIT.md`](ENVIRONMENT_AUDIT.md) | Toolchain availability and how CI supplies it |
| [`TEST_REPORT.md`](TEST_REPORT.md) | Every test command and its real result |
| [`PERFORMANCE_REPORT.md`](PERFORMANCE_REPORT.md) | Measured budgets (and what is *not* measured) |
| [`ANDROID_BUILD_GUIDE.md`](ANDROID_BUILD_GUIDE.md) | Reproduce the APK, or sign a release |
| [`ROADMAP.md`](ROADMAP.md) | Next milestones toward the full six-continent vision |
| [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) | Declared limitations, not surprises |
