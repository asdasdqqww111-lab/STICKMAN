#!/usr/bin/env python3
"""Dump structure facts (animations, bones, meshes, materials) from GLB/GLTF files."""
import json, struct, sys, pathlib

def load_glb(p):
    b = p.read_bytes()
    magic, ver, length = struct.unpack_from('<4sII', b)
    assert magic == b'glTF'
    off = 12; doc = None
    while off < len(b):
        clen, ctype = struct.unpack_from('<II', b, off); off += 8
        if ctype == 0x4E4F534A: doc = json.loads(b[off:off+clen])
        off += clen
    return doc

def load_gltf(p):
    return json.loads(p.read_text())

def report(p):
    doc = load_glb(p) if p.suffix == '.glb' else load_gltf(p)
    anims = [a.get('name') for a in doc.get('animations', [])]
    nodes = [n.get('name') for n in doc.get('nodes', [])]
    skins = doc.get('skins', [])
    joints = []
    if skins:
        joints = [nodes[j] for j in skins[0]['joints']]
    prims = sum(len(m.get('primitives', [])) for m in doc.get('meshes', []))
    print(f"== {p.name}: nodes={len(nodes)} meshes={len(doc.get('meshes',[]))} prims={prims} anims={len(anims)} skins={len(skins)}")
    if anims: print("   anims:", ", ".join(sorted(set(anims))))
    if joints: print("   joints:", ", ".join(joints[:40]))
    mats = [m.get('name') for m in doc.get('materials', [])]
    print("   materials:", mats)
    imgs = [(i.get('mimeType'), i.get('uri')) for i in doc.get('images', [])]
    print("   images:", imgs[:5])

for arg in sys.argv[1:]:
    report(pathlib.Path(arg))
