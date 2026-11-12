#!/usr/bin/env python3
"""Reproducible download of the third-party CC0 assets used by MICRO WORLD: LIVING.

Every downloaded file is recorded in assets/vendor/ASSET_MANIFEST.json together with
its upstream repository, commit SHA, licence and SHA-256 hash so an auditor can
re-fetch and verify the exact bytes the game ships with.

Usage:
    python3 tools/fetch_assets.py            # download everything that is missing
    python3 tools/fetch_assets.py --force    # re-download and rewrite the manifest
    python3 tools/fetch_assets.py --verify   # verify existing files against manifest

The script only talks to api.github.com / raw.githubusercontent.com and uses the
GitHub REST API (optionally authenticated through GH_TOKEN) to resolve the tree.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / "assets" / "vendor"
MANIFEST = VENDOR / "ASSET_MANIFEST.json"
API = "https://api.github.com"

TOKEN = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN") or ""

# ---------------------------------------------------------------------------
# Source definitions.  `pick` selects blobs from the upstream tree.
# ---------------------------------------------------------------------------
SOURCES = [
    {
        "id": "kaykit-adventurers",
        "repo": "KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0",
        "licence": "CC0-1.0",
        "licence_file": "LICENSE.txt",
        "attribution": "Kay Lousberg (kaylousberg.com) — KayKit Adventurers Character Pack",
        "target": "characters/adventurers",
        "pick": [
            "Characters/gltf/Knight.glb",
            "Characters/gltf/Mage.glb",
            "Characters/gltf/Rogue.glb",
            "Characters/gltf/Barbarian.glb",
            "Characters/gltf/knight_texture.png",
            "Characters/gltf/mage_texture.png",
            "Characters/gltf/rogue_texture.png",
        ],
        "weapons": [
            "gltf/sword_1handed.gltf",
            "gltf/sword_1handed.bin",
            "gltf/sword_2handed.gltf",
            "gltf/sword_2handed.bin",
            "gltf/shield_round.gltf",
            "gltf/shield_round.bin",
            "gltf/staff.gltf",
            "gltf/staff.bin",
            "gltf/dagger.gltf",
            "gltf/dagger.bin",
            "gltf/axe_1handed.gltf",
            "gltf/axe_1handed.bin",
            "gltf/barbarian_texture.png",
            "gltf/knight_texture.png",
            "gltf/mage_texture.png",
            "gltf/rogue_texture.png",
        ],
    },
    {
        "id": "kaykit-skeletons",
        "repo": "KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0",
        "licence": "CC0-1.0",
        "licence_file": "LICENSE.txt",
        "attribution": "Kay Lousberg (kaylousberg.com) — KayKit Skeletons Character Pack",
        "target": "characters/skeletons",
        "pick": [
            "Characters/gltf/Skeleton_Minion.glb",
            "Characters/gltf/Skeleton_Warrior.glb",
            "Characters/gltf/Skeleton_Mage.glb",
            "Characters/gltf/Skeleton_Rogue.glb",
        ],
    },
    {
        "id": "kaykit-dungeon",
        "repo": "KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0",
        "licence": "CC0-1.0",
        "licence_file": "LICENSE.txt",
        "attribution": "Kay Lousberg (kaylousberg.com) — KayKit Dungeon Remastered",
        "target": "dungeon",
        "pick": [
            "Assets/floor_tile_big_spikes.glb",
            "Assets/floor_tile_big_grate_open.gltf.glb",
            "Assets/floor_tile_big_grate.gltf.glb",
            "Assets/wall.gltf.glb",
            "Assets/wall_corner.gltf.glb",
            "Assets/wall_doorway.gltf.glb",
            "Assets/wall_doorway_scaffold.glb",
            "Assets/wall_pillar.gltf.glb",
            "Assets/pillar.gltf.glb",
            "Assets/torch_mounted.gltf.glb",
            "Assets/torch_lit.gltf.glb",
            "Assets/chest.glb",
            "Assets/chest_gold.glb",
            "Assets/coin.gltf.glb",
            "Assets/coin_stack_small.gltf.glb",
            "Assets/barrel_large.gltf.glb",
            "Assets/crates_stacked.gltf.glb",
            "Assets/candle_lit.gltf.glb",
            "Assets/stairs.gltf.glb",
            "Assets/rubble_half.gltf.glb",
            "Assets/banner_red.gltf.glb",
        ],
    },
    {
        "id": "kaykit-city",
        "repo": "KayKit-Game-Assets/KayKit-City-Builder-Bits-1.0",
        "licence": "CC0-1.0",
        "licence_file": "LICENSE.txt",
        "attribution": "Kay Lousberg (kaylousberg.com) — KayKit City Builder Bits",
        "target": "city",
        "pick": [
            "gltf/building_A.gltf",
            "gltf/building_A.bin",
            "gltf/building_B.gltf",
            "gltf/building_B.bin",
            "gltf/building_C.gltf",
            "gltf/building_C.bin",
            "gltf/bush.gltf",
            "gltf/bush.bin",
            "gltf/bench.gltf",
            "gltf/bench.bin",
            "gltf/box_A.gltf",
            "gltf/box_A.bin",
            "gltf/road_straight.gltf",
            "gltf/road_straight.bin",
            "gltf/citybits_texture.png",
        ],
    },
    {
        "id": "kenney-rpg-audio",
        "repo": "Boyquotes/kenney-rpg-audio-for-godot",
        "licence": "CC0-1.0",
        "licence_file": "LICENSE",
        "attribution": "Kenney.nl (kenney.nl) — RPG Audio, Godot port by Boyquotes",
        "target": "audio",
        "pick": [
            "addons/kenney rpg audio/knife_slice.ogg",
            "addons/kenney rpg audio/knife_slice_2.ogg",
            "addons/kenney rpg audio/footstep_0.ogg",
            "addons/kenney rpg audio/footstep_1.ogg",
            "addons/kenney rpg audio/footstep_2.ogg",
            "addons/kenney rpg audio/footstep_3.ogg",
            "addons/kenney rpg audio/handle_coins.ogg",
            "addons/kenney rpg audio/handle_coins_2.ogg",
            "addons/kenney rpg audio/metal_pot_1.ogg",
            "addons/kenney rpg audio/metal_click.ogg",
            "addons/kenney rpg audio/book_flip_1.ogg",
            "addons/kenney rpg audio/door_open_1.ogg",
            "addons/kenney rpg audio/door_close_1.ogg",
            "addons/kenney rpg audio/draw_knife_1.ogg",
            "addons/kenney rpg audio/cloth_1.ogg",
        ],
    },
]


def api(path: str) -> dict:
    """GET an api.github.com path, honouring a token when present."""
    req = urllib.request.Request(API + path, headers={"Accept": "application/vnd.github+json"})
    if TOKEN:
        req.add_header("Authorization", f"Bearer {TOKEN}")
    with urllib.request.urlopen(req, timeout=60) as resp:  # noqa: S310 - fixed host
        return json.load(resp)


def download(repo: str, sha: str, path: str, blob_sha: str = "") -> bytes:
    """Fetch one blob at a pinned commit.

    Tries the raw CDN first, then the git blobs API (which handles files up to
    100 MB -- the contents API refuses anything larger than 1 MB) and finally the
    contents API for small files.
    """
    url = f"https://raw.githubusercontent.com/{repo}/{sha}/{urllib.request.quote(path)}"
    req = urllib.request.Request(url)
    if TOKEN:
        req.add_header("Authorization", f"Bearer {TOKEN}")
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:  # noqa: S310
            return resp.read()
    except (urllib.error.URLError, urllib.error.HTTPError):
        pass
    if blob_sha:
        blob = api(f"/repos/{repo}/git/blobs/{blob_sha}")
        if blob.get("encoding") == "base64":
            return base64.b64decode(blob["content"])
    blob = api(f"/repos/{repo}/contents/{urllib.request.quote(path)}?ref={sha}")
    if blob.get("encoding") == "base64":
        return base64.b64decode(blob["content"])
    raise RuntimeError(f"cannot fetch {repo}:{path}")


def tree(repo: str, sha: str) -> dict[str, dict]:
    """Index the pinned tree by full path *and* by basename.

    Pack repositories move their payload between the repository root and an
    `addons/<pack>/` folder between commits, so a wanted path such as
    `gltf/bush.gltf` may only exist as `addons/<pack>/gltf/bush.gltf` at the
    commit we pin.  Basenames inside a pack are unique, so resolving by
    basename keeps the manifest stable.
    """
    data = api(f"/repos/{repo}/git/trees/{sha}?recursive=1")
    index: dict[str, dict] = {}
    for item in data["tree"]:
        if item["type"] != "blob":
            continue
        path = item["path"]
        index[path] = {**item, "_resolved": path}
        base = path.rsplit("/", 1)[-1]
        # Prefer the shallowest match so vendored copies stay predictable.
        if base not in index or path.count("/") < index[base]["_resolved"].count("/"):
            index[base] = {**item, "_resolved": path}
    return index


def resolve_sha(repo: str) -> str:
    return api(f"/repos/{repo}/commits?per_page=1")[0]["sha"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()

    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {"sources": {}, "files": {}}
    VENDOR.mkdir(parents=True, exist_ok=True)

    if args.verify:
        bad = 0
        for rel, meta in manifest["files"].items():
            target = ROOT / rel
            if not target.exists():
                print(f"MISSING {rel}")
                bad += 1
                continue
            digest = hashlib.sha256(target.read_bytes()).hexdigest()
            if digest != meta["sha256"]:
                print(f"CORRUPT {rel}")
                bad += 1
        print(f"verified {len(manifest['files'])} files, {bad} problem(s)")
        return 1 if bad else 0

    total = 0
    for source in SOURCES:
        repo = source["repo"]
        if source["id"] in manifest["sources"] and not args.force:
            sha = manifest["sources"][source["id"]]["commit"]
        else:
            sha = resolve_sha(repo)
            print(f"resolved {repo} -> {sha[:10]}")
        available = tree(repo, sha)
        wanted = list(source["pick"]) + list(source.get("weapons", []))
        if source["licence_file"] not in wanted:
            wanted.append(source["licence_file"])
        manifest["sources"][source["id"]] = {
            "repo": repo,
            "commit": sha,
            "licence": source["licence"],
            "attribution": source["attribution"],
        }
        for path in wanted:
            if path not in available and path.rsplit("/", 1)[-1] not in available:
                print(f"  !! {repo} has no '{path}' (skipped)")
                continue
            resolved = available[path]["_resolved"] if path in available else available[path.rsplit("/", 1)[-1]]["_resolved"]
            suffix = Path(path).suffix
            if path.endswith(".gltf.glb"):
                suffix = ".glb"
            stem = Path(path).name
            if path == source["licence_file"]:
                stem = f"LICENSE-{source['id']}{suffix or '.txt'}"
            rel = Path("assets/vendor") / source["target"] / stem
            target = ROOT / rel
            expected = available[path if path in available else path.rsplit("/", 1)[-1]].get("sha")  # git blob sha, not content sha
            if target.exists() and not args.force and rel.as_posix() in manifest["files"]:
                total += 1
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            try:
                payload = download(repo, sha, resolved, expected)
            except Exception as exc:  # noqa: BLE001 - reported, build continues
                print(f"  !! failed {repo}:{path}: {exc}")
                continue
            target.write_bytes(payload)
            manifest["files"][rel.as_posix()] = {
                "repo": repo,
                "commit": sha,
                "upstream_path": resolved,
                "git_blob": expected,
                "sha256": hashlib.sha256(payload).hexdigest(),
                "bytes": len(payload),
                "licence": source["licence"],
            }
            total += 1
            time.sleep(0.05)
            print(f"  + {rel.as_posix()} ({len(payload)} B)")

    MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"manifest written: {MANIFEST.relative_to(ROOT)} ({total} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
