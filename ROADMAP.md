# Roadmap — MICRO WORLD: LIVING

Guiding rule from the brief: **the playable loop and the export come before continents.** The loop
and the export exist. Everything below is ordered by what unblocks the most players per unit of work.

## Shipped (this branch)

- [x] Cube-sphere planet, analytic gravity, third-person camera
- [x] Player with the KayKit rig: move, run, jump, dodge, light/heavy attack, cast, interact
- [x] Combat resolution, crits, armour, 6 spells in 3 schools, 10 monster archetypes, 3-phase boss
- [x] Havenbrook village, 5 shrines, 24 nodes, 4 chests, 10 camps, barrow dungeon
- [x] Level/XP, 3 skills, guild F→E→D, 15 quests, 24 items, 8 recipes, shop economy
- [x] NPC daily schedules, day/night clock, simulation LOD, autosave
- [x] Full touch UI: menu, HUD, 11 panels, joystick + action buttons, safe areas
- [x] Save v4 with atomic writes, backup, corruption recovery, v1→v4 migration
- [x] Debug APK built and verified by CI, published as a Release
- [x] Automated tests (718 assertions) + static asset verification (268) + benchmark

## Milestone 1 — close the honesty gaps (next)

- [ ] Install the release APK on a physical Android 9 and Android 13 device; record FPS with the
      in-game overlay into `PERFORMANCE_REPORT.md` (**blocked on hardware, not on code**)
- [ ] Chunked terrain: split each face into 4×4 chunks with per-chunk LOD and async upload
      (removes the ~1 s startup cost and is the prerequisite for a bigger planet)
- [ ] Dungeon interior collision: replace the analytic sphere with a trimesh collider while inside
- [ ] `CharacterBody3D`-based enemies with a simple navigation layer
- [ ] Draw-call optimisation: merge static props per query, `MultiMesh` for repeated dungeon pieces

## Milestone 2 — depth in the existing world

- [ ] Boss movesets per phase (slam, summon, sweep) instead of stat multipliers
- [ ] Ranged/kiting monster behaviour and telegraphed wind-ups
- [ ] Passive wildlife (deer, birds) on the `PASSIVE` archetypes
- [ ] Dialogue trees for villagers; quest chains beyond the registrar
- [ ] Armour visuals (skinned modular pieces)
- [ ] Building: place/upgrade 3 structures at owned plots
- [ ] Music and ambient beds (CC0 only)

## Milestone 3 — the wider world

- [ ] Second and third continents as distinct cube-face regions of a larger radius
- [ ] Additional settlements and interiors (instanced interiors, not another planet scene)
- [ ] Rank C tuning, then B/A/S with promotion trials as instanced encounters
- [ ] Weather, seasons, and time-dependent AI
- [ ] Regional economy (prices that react to player selling)
- [ ] Localisation scaffold (Arabic + English), RTL layout verification

## Milestone 4 — release engineering

- [ ] Release keystore held in CI secrets only; `--export-release` AAB
- [ ] Play Console internal track, staged rollout, crash reporting
- [ ] Device matrix testing (3 tiers × 2 Android versions)
- [ ] Automated screenshot regression for the UI

## Explicitly out of scope

Online play, PvP, monetisation, cloud saves, user-generated content, a full six-continent map in a
single release. The brief's six-continent vision is a direction, not a near-term deliverable, and
pretending otherwise would collapse the frame budget and the content pipeline at once.
