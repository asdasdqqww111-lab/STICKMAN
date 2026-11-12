#!/usr/bin/env python3
"""Validate basic GLB containers and source references without a Godot install."""
import json
import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parents[1]
assets = [
    'assets/gobkit/TreeMed001.glb',
    'assets/gobkit/Rock001.glb',
    'assets/gobkit/Bush001.glb',
    'assets/city/casa_simples.glb',
]
main = (ROOT / 'scripts/main.gd').read_text()
showcase = (ROOT / 'scripts/asset_showcase.gd').read_text()
for name in assets:
    blob = (ROOT / name).read_bytes()
    magic, version, length = struct.unpack_from('<4sII', blob)
    assert magic == b'glTF' and version == 2 and length == len(blob), name
    json_length, chunk_type = struct.unpack_from('<II', blob, 12)
    assert chunk_type == 0x4e4f534a and 20 + json_length <= len(blob), name
    doc = json.loads(blob[20:20 + json_length])
    assert doc.get('meshes') and doc.get('materials') and doc.get('scenes'), name
    assert all(not image.get('uri') for image in doc.get('images', [])), name
    assert all(not buf.get('uri') for buf in doc.get('buffers', [])), name
    assert 'res://' + name in main and 'res://' + name in showcase, name
    print('PASS', name, 'GLB structure, embedded resources, source references')
for name in ['assets/gobkit/LICENSE', 'assets/city/LICENSE']:
    assert 'CC0' in (ROOT / name).read_text(), name
    print('PASS', name, 'license notice present')
