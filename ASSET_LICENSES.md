# Asset licences — MICRO WORLD: LIVING

**Summary: every third-party asset shipped in this repository is CC0 1.0 (public domain
dedication). No attribution is legally required; it is provided here anyway, and every file is
hashed in [`assets/vendor/ASSET_MANIFEST.json`](assets/vendor/ASSET_MANIFEST.json).**

Nothing in the shipped build is "licence unknown". Assets that could not be verified were not
downloaded at all.

## Sources

| # | Source | Licence | Pinned commit | Files | Size |
| --- | --- | --- | --- | --- | --- |
| 1 | [`KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0`](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0) | CC0-1.0 | `672074b73ba276876a19e8816ecdc5241817ab47` | 21 | 14.0 MB |
| 2 | [`KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0`](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0) | CC0-1.0 | `15b62b9bad122f72926c10fb14d622c73819fa54` | 5 | 18.4 MB |
| 3 | [`KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0`](https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0) | CC0-1.0 | `b0ca9bd96a8072ab36a3a5464f00ed1e06a16d07` | 21 | 1.0 MB |
| 4 | [`KayKit-Game-Assets/KayKit-City-Builder-Bits-1.0`](https://github.com/KayKit-Game-Assets/KayKit-City-Builder-Bits-1.0) | CC0-1.0 | `63976910ca04d16f0fc531b9c614244be8128713` | 16 | 0.2 MB |
| 5 | [`Boyquotes/kenney-rpg-audio-for-godot`](https://github.com/Boyquotes/kenney-rpg-audio-for-godot) (Kenney.nl RPG Audio, Godot port) | CC0-1.0 | `22eb79bb843bbcadcaa6ed119353a33265ffad11` | 16 | 0.24 MB |

**79 files, 35.5 MB of source assets**, all fetched by `tools/fetch_assets.py`.

### Verified licence text

Upstream `LICENSE`/`LICENSE.txt` files are vendored next to the assets:

- `assets/vendor/characters/adventurers/LICENSE-kaykit-adventurers.txt`
- `assets/vendor/characters/skeletons/LICENSE-kaykit-skeletons.txt`
- `assets/vendor/dungeon/LICENSE-kaykit-dungeon.txt`
- `assets/vendor/city/LICENSE-kaykit-city.txt`
- `assets/vendor/audio/LICENSE-kenney-rpg-audio.txt`

Each states, verbatim in the KayKit packs:

> License: (Creative Commons Zero, CC0) … This content is free to use in personal, educational and
> commercial projects.

Kenney's RPG Audio is released under CC0 1.0 as well; the vendored licence file is the
authoritative copy.

## Attribution (not required, given gladly)

- **Kay Lousberg** — https://www.kaylousberg.com — KayKit Adventurers, Skeletons, Dungeon
  Remastered, City Builder Bits.
- **Kenney** — https://kenney.nl — RPG Audio sound pack.
- **Boyquotes** — Godot-ready port of Kenney's RPG Audio.

## Rejected / not used

| Candidate | Reason |
| --- | --- |
| `Ariescar/gobkit-free-assets` | Repository reports `NOASSERTION`; the two GLBs previously vendored here had a CC0 file notice but the pack has no project-level licence file. Replaced by KayKit. |
| `kenney.nl` asset ZIPs | The sandbox cannot reach `kenney.nl`; the CC0 Godot port above provides the same audio. |
| `Quaternius` / `KenneyNL` GitHub orgs | No such public organisations are reachable; the official distribution is not hosted on an allowed host. |
| Unity `.fbx` payloads inside the KayKit packs | Imported only as `.glb`/`.gltf`; FBX files are not vendored, keeping mobile import fast and the repository small. |

## Adding assets

1. Confirm the licence at the *original* source (not a mirror).
2. Add an entry to `SOURCES`/`pick` in `tools/fetch_assets.py` with the licence id.
3. Run `python3 tools/fetch_assets.py --force` — it records repo, commit, upstream path,
   SHA-256 and byte size per file.
4. Register the path in `scripts/core/asset_catalog.gd` (`REQUIRED_PATHS`), otherwise
   `tests/test_combat.gd::_test_asset_catalog` will fail the build.
5. Run `python3 tools/fetch_assets.py --verify` to prove the working tree matches the manifest.
