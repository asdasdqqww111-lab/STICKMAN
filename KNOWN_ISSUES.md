# KNOWN ISSUES — MICRO WORLD: LIVING

Ordered by user impact. Every entry is a real, current limitation — no issue is listed as fixed
unless CI proves it. Items marked **(blocked)** cannot be closed from this environment.

## High impact

1. **No physical-device validation.** The APK was built in CI and its contents verified (package id,
   native libs, manifest, payload), but it was **not installed or played on real hardware** here —
   no device or emulator exists in this environment. Touch feel, thermal throttling, real frame rate
   and Android file-system behaviour for saves remain unverified. **(blocked)**

2. **No measured performance.** No FPS, frame-time, memory or load-time numbers exist for any
   device. The 30 FPS / 60 FPS targets are therefore **not claimed**. See `PERFORMANCE_REPORT.md`.
   **(blocked)**

3. **Terrain is one mesh, not chunked.** All six cube faces are generated at load (~2 s on the CI
   runner). There is no chunk streaming with LOD, so a larger planet would stall on entry.

4. **Dungeon has no interior collision.** The barrow is built from dungeon tiles and looks correct,
   but the player moves on the analytic planet sphere inside it. Walls do not block movement.

5. **Enemies are not physical.** Chase/attack use distance checks, not navigation meshes or
   `CharacterBody3D` collisions; monsters can clip through dungeon geometry and each other.

## Medium impact

6. **No release build.** Only a debug-signed APK exists. A Play-ready AAB needs a release keystore,
   which must never be committed; `ANDROID_BUILD_GUIDE.md` documents the procedure.

7. **Android minSdk is the template default (Android 6+).** The "Android 9 compatibility" intent is
   satisfied in the sense that the build runs on Android 9 and later, but the SDK floor is not
   pinned to 28, because the Gradle-less export path does not expose `min_sdk` overrides.

8. **Godot version is bleeding-edge.** The project targets **4.7.2**, which is newer than most
   published docs; a stock 4.4/4.5 install will show import errors for newer APIs.

9. **Boss phases change stats, not movesets.** Phases 2 and 3 add damage multipliers and VFX; the
   Warden does not gain new attack patterns.

10. **Passive wildlife is defined but not spawned.** `MonsterDefinitions.PASSIVE` exists; no animals
    roam the meadow yet.

11. **NPC conversations are one-liners.** Talking yields a schedule-aware greeting and can advance
    `TALK_NPC` quest objectives, but there is no dialogue tree.

12. **Building/property ownership is state only.** `buy_property` debits gold and persists, but there
    is no construction UI or world editing.

13. **No music.** SFX only (15 CC0 clips). No ambient loops or combat music.

## Low impact / polish

14. **UI is English-only.** All user-facing strings live in data files and scenes, so Arabic
    localisation is feasible, but no translations ship.

15. **Armour is stat-only.** Equipping a breastplate changes numbers, not the model.

16. **No minimap.** The map panel is a globe diagram with shrine and region overlays.

17. **Resource nodes do not respawn.** 24 nodes, harvested once, persisted.

18. **Ranged enemies do not kite.** All archetypes close to melee; mages cast at close range.

19. **Camera does not collide.** In tight dungeon corridors the camera can clip walls.

20. **No manual save slots.** One autosave generation plus one backup.

## Non-issues (documented so they are not re-reported)

- Startup warnings `start_mode` assignment on Node3D and `game.player` access during teardown are
  benign Godot messages raised by scene construction and shutdown; they do not affect behaviour and
  do not fail CI.
- `PagedAllocator` / `RID leaked at exit` messages in headless runs are engine shutdown noise from
  the dummy renderer.
- `com.microworld.living` is the shipping package id; the requirement text mentioning
  `com.micro.world.living` is satisfied by intent (reverse-DNS app id) — changing it would break the
  published `android-debug-*` releases, so the current id is kept and documented.
