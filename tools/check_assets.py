#!/usr/bin/env python3
"""Static verification of vendored assets: manifest integrity, GLB structure,
animation and bone availability, and that every catalogued asset exists on disk.

Runs without Godot so it can gate the APK build before the engine is involved.
Exit code 0 = every check passed.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets" / "vendor" / "ASSET_MANIFEST.json"
CATALOG = ROOT / "scripts" / "core" / "asset_catalog.gd"

failures: list[str] = []


def check(condition: bool, message: str) -> None:
    if condition:
        print(f"PASS  {message}")
    else:
        failures.append(message)
        print(f"FAIL  {message}")


def read_glb_json(path: pathlib.Path) -> dict | None:
    blob = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", blob)
    if magic != b"glTF" or version != 2 or length != len(blob):
        return None
    offset = 12
    while offset < len(blob):
        chunk_length, chunk_type = struct.unpack_from("<II", blob, offset)
        offset += 8
        if chunk_type == 0x4E4F534A:
            return json.loads(blob[offset:offset + chunk_length])
        offset += chunk_length
    return None


def read_gltf_json(path: pathlib.Path) -> dict | None:
    return json.loads(path.read_text())


def main() -> int:
    manifest = json.loads(MANIFEST.read_text())

    # 1. every file listed in the manifest exists with the recorded hash
    for rel, meta in manifest["files"].items():
        target = ROOT / rel
        check(target.exists(), f"present: {rel}")
        if not target.exists():
            continue
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        check(digest == meta["sha256"], f"sha256 matches source: {rel}")

    # 2. catalogued assets exist on disk
    catalog_text = CATALOG.read_text()
    import re
    catalog_paths = sorted(set(re.findall(r'"(res://assets/[^"]+)"', catalog_text)))
    check(len(catalog_paths) >= 40, f"asset catalog lists {len(catalog_paths)} paths")
    for path in catalog_paths:
        fs_path = ROOT / path.replace("res://", "")
        check(fs_path.exists(), f"catalogued asset exists: {path}")

    # 3. rigged characters carry the clips and hand bones the game drives
    required_clips = [
        "Idle", "Walking_A", "Running_A", "1H_Melee_Attack_Slice_Horizontal",
        "2H_Melee_Attack_Chop", "Dodge_Forward", "Hit_A", "Death_A", "Interact",
        "Spellcast_Shoot", "Jump_Start",
    ]
    characters = [
        "assets/vendor/characters/adventurers/Knight.glb",
        "assets/vendor/characters/adventurers/Mage.glb",
        "assets/vendor/characters/adventurers/Rogue.glb",
        "assets/vendor/characters/adventurers/Barbarian.glb",
        "assets/vendor/characters/skeletons/Skeleton_Minion.glb",
        "assets/vendor/characters/skeletons/Skeleton_Warrior.glb",
        "assets/vendor/characters/skeletons/Skeleton_Mage.glb",
        "assets/vendor/characters/skeletons/Skeleton_Rogue.glb",
    ]
    for rel in characters:
        path = ROOT / rel
        doc = read_glb_json(path) if path.suffix == ".glb" else read_gltf_json(path)
        check(doc is not None, f"valid GLB: {rel}")
        if not doc:
            continue
        clips = {a.get("name") for a in doc.get("animations", [])}
        missing = [c for c in required_clips if c not in clips]
        check(not missing, f"{path.name} has all {len(required_clips)} gameplay clips"
                           + (f" (missing {missing})" if missing else ""))
        nodes = [n.get("name") for n in doc.get("nodes", [])]
        check("hand.r" in nodes and "hand.l" in nodes, f"{path.name} exposes hand bones for weapons")
        check(bool(doc.get("skins")), f"{path.name} is skinned (rigged)")

    # 4. weapons are separate meshes that can be socketed
    for rel in ["sword_1handed.gltf", "sword_2handed.gltf", "staff.gltf", "dagger.gltf",
                "axe_1handed.gltf", "shield_round.gltf"]:
        path = ROOT / "assets/vendor/characters/adventurers" / rel
        doc = read_gltf_json(path) if path.exists() else None
        check(doc is not None and bool(doc.get("meshes")), f"weapon mesh: {rel}")

    # 5. audio files are valid Ogg Vorbis containers
    for ogg in sorted((ROOT / "assets/vendor/audio").glob("*.ogg")):
        with ogg.open("rb") as handle:
            head = handle.read(4)
        check(head == b"OggS", f"valid Ogg container: {ogg.name}")

    print()
    if failures:
        print(f"{len(failures)} asset check(s) FAILED")
        return 1
    print("all asset checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
