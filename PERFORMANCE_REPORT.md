# Performance report — MICRO WORLD: LIVING

## Honesty statement, first

**No frame rate was measured on any Android device, because no device or emulator is available in
this environment.** The 30 FPS (mid-range) and 60 FPS (high-end) targets are therefore **not
claimed, not met, not disproved** — they are unverified targets. Any number below is labelled with
exactly where it was measured.

What *is* measurable is the cost of the code this project wrote: world generation, terrain sampling,
region queries and the per-frame simulation budget. Those numbers follow, taken from the headless
benchmark that CI runs on every push (`tests/benchmark.gd`, log at `.ci/last-run/benchmark.log`).

## Measured: world generation (headless, CPU, CI runner)

Command: `godot --headless --path . --script tests/benchmark.gd`

<!-- BENCHMARK_RESULTS -->

## Structural budgets (by construction, not by benchmark)

These are hard caps in the code, chosen to keep a mid-range phone out of trouble. They are enforced
by settings and asserted where possible:

| Budget | Value | Where |
| --- | --- | --- |
| Planet quads | 16 × 16 × 6 faces = 1,536 quads, ≈3.1k triangles, 14 draw calls (6 face meshes + ocean shell + sky) | `planet_mesh.DEFAULT_RESOLUTION` |
| Quality scaling | Low `planet_resolution = 12`, render scale 0.6, no shadows; High = 16, 1.0, shadows | `game_settings.QUALITY_PRESETS` |
| Active monsters | 24 simulated, 32 max by preset | `world_simulation.max_active_monsters` |
| Monster draw distance | 45 m simulation, culled beyond 81 m | `world_simulation.simulation_distance` |
| Prop streaming | 2-region radius (≈66 m) | `world_simulation.stream_radius` |
| Physics tick | 30 Hz | `project.godot` |
| Frame cap | 60 FPS | `Engine.max_fps` in `game_world` |
| Per-region props | ≤ 14 instances per region | `world_builder` |
| Dungeon lights | 6 OmniLights, radius 9 m each | `dungeon_builder` |
| Audio voices | 1 pooled `AudioStreamPlayer` per channel set, no voice explosion | `audio_manager` |

## On-device measurement, now built in

Because a real device profile cannot be taken here, the game ships the instrument to take it:

- **Settings → Performance overlay** toggles a live panel (persisted in `user://settings.cfg`).
- It reports **current FPS, rolling average, 1 % low, draw calls, node count, active simulated
  monsters and the active quality preset** — sampled from the real frame loop, not estimated.
- `game_world.average_fps()` and `game_world.low_fps_percentile()` expose the same numbers for
  logging or automated device tests.

To produce the missing table, install the release APK on a device and record the overlay at
Havenbrook, in the meadow during combat, and in the barrow:

```bash
adb install -r MICRO-WORLD-LIVING-<run>-debug.apk
adb logcat -s godot:V   # engine output alongside the overlay
```

## Known risks to the frame budget

1. **`MeshInstance3D` count, not triangle count, is the risk.** ~300 prop instances in view (each
   dungeon/city prop is a separate mesh) — this is where draw calls will hurt on low-end GPUs.
   MultiMesh/instance batching is the next optimisation, not terrain LOD.
2. **No texture compression tuning beyond `import_etc2_astc = true`.** All vendor textures are small;
   this is safe today, fragile if large textures are added.
3. **Terrain is generated on the main thread at load** (see `planet_mesh` — a worker thread is used
   for the heavy faces, but the final `ArrayMesh` upload is synchronous). Startup, not steady state.
4. **HUD redraw cost.** `hud.refresh()` runs every frame and rebuilds several labels; on device this
   should become dirty-flag driven if profiling shows it matters.

## What would make this report complete

| Missing measurement | Blocking requirement |
| --- | --- |
| FPS at 3 representative scenes on 2 device tiers | Physical Android hardware (or an emulator with GPU) |
| Frame time breakdown (CPU/GPU) | Same |
| Memory ceiling / peak RSS | Same |
| APK cold-start time on device | Same |
| Thermal throttling over 20 minutes | Same |
