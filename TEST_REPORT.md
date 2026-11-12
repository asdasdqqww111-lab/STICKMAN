# Test report — 2026-11-11

## Environment and limits
Godot `4.7.2.stable.custom_build` was compiled locally from the official `4.7.2-stable` source tag for Linux x86_64. X11, Wayland, Vulkan, OpenGL, ALSA, PulseAudio, D-Bus and udev were disabled to obtain a headless test tool. This is not an official binary and cannot verify graphical output, touch input, or Android. GitHub's latest-release API reported 4.7.2 stable. The standard release executable could not be downloaded because its redirected host was blocked.

## Executed
- Editor scan/import: `godot --headless --path . --editor --quit` — exited 0 and reported import of all 4 GLBs. Two editor-theme warnings appeared in this custom headless build. The three Gobkit embedded textures were extracted by Godot to adjacent `_0.png` files. No visual verification performed.
- `tests/test_core.gd` — 15 checks passed, exit 0: initial state; contract; pre-contract kills; idempotent kills and discovery; objective and single reward; leveling; spherical coordinate round trip and surface movement; state JSON round trip; rejection without partial mutation; save and prior-generation backup; corrupted-primary recovery. The first run emitted an expected JSON error for the intentionally corrupted save; parser handling was adjusted and the final run had no stderr.
- `tests/test_scene.gd` — 12 checks passed, exit 0: bounded initial cell set; four imported packed scenes load; eight enemies spawn; quest acceptance; combat and spell state; three kills and turn-in; region transition and discovery. This runs headlessly and invokes actions directly rather than simulating real screen input or rendering.
- Main scene headless for 180 frames and `AssetShowcase.tscn` headless for 30 frames — both exited 0 without errors. This proves only initialization and execution without a renderer, not visual correctness or interactive playability.
- `python3 tests/test_assets.py` — 4 GLB container/reference checks and 2 local license-notice checks passed. These are basic structural checks, not legal advice or visual verification.
- Tree-sitter GDScript parser scanned six scripts and two GDScript test files with no syntax-error nodes; this was supplementary and does not replace Godot parsing/execution.
- `git diff --check` — passed.

## Not executed
No GUI playthrough, visual/material inspection, touchscreen test, Android build/install/resume test, FPS or memory benchmark, terrain collision test, attack hitbox test, long-duration world simulation or device compatibility test. Features absent from this slice cannot pass their requested acceptance tests. No APK or AAB was produced.

## Follow-up: two contracts, gathering, crafting and ranks

Using the same locally compiled headless Godot 4.7.2, with an isolated `HOME`:

- `tests/test_core.gd` — **33 checks passed**, exit 0. In addition to the earlier checks, this covers version-1 save migration, pre-contract gathering, finite pickup idempotence, unrelated kills, F→E→D requirements, resource deductions, sword damage, potion healing, invalid/duplicate inventory rejection, and refusal to overwrite a future-version save.
- `tests/test_scene.gd` — **21 checks passed**, exit 0. The test invokes gameplay functions directly: it accepts the contracts, gathers five scene pickups, earns E at the registrar, forges and uses the potion, saves/reloads, and verifies collected pickups, defeated slimes and sword visibility state in a newly instantiated scene.
- Main scene ran headlessly for 180 frames, exit 0. `python3 tests/test_assets.py` passed 6 checks; `git diff --check` passed.

The 33 and 21 replace the earlier counts for the current revision. These tests do not prove rendered appearance, actual input behavior, Android compatibility or performance. The earlier headless showcase/import results still apply to the unchanged assets; no new third-party assets were added in this follow-up.

## Follow-up: partition, discovery map and travel

On the same custom Godot 4.7.2 headless build, in an isolated `HOME`:

- `tests/test_core.gd`: **33 checks passed** (exit 0).
- `tests/test_scene.gd`: **30 checks passed** (exit 0), including map open/close and touch-state clearing, locked destinations, activation by interaction, origin/destination enemy guards, travel-button callback, seam transition, and waypoint persistence after reload. Tests call scene methods or emit signals; they are not touch-device or rendered-UI tests.
- `tests/test_world.gd`: **18 checks passed** (exit 0). These include 3,000 seeded sampled directions, six face centers, all 24 directed face-edge samples, the longitude seam and a pole, bounded/deduplicated neighborhoods, version-2 migration, preservation of old IDs and exploration credit, and waypoint validation/round-trip. This is not an exhaustive proof of all corner transitions or precision behavior.
- The main scene ran headlessly for 180 frames (exit 0). The editor scan exited 0 with the same custom headless editor-theme warnings as before. `python3 tests/test_assets.py` passed 6 checks; `git diff --check` passed. No new third-party assets.

Current automated Godot checks total **81** (33 + 30 + 18). No visual map inspection, touchscreen test, Android build/device test or performance benchmark was performed.
