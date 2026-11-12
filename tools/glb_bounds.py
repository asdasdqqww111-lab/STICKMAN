#!/usr/bin/env python3
"""Report POSITION bounds (model size in metres) for GLB/GLTF assets."""
import json, struct, sys, pathlib
def load(p):
    b=p.read_bytes()
    if p.suffix=='.glb':
        off=12; doc=None
        while off<len(b):
            clen,ctype=struct.unpack_from('<II',b,off); off+=8
            if ctype==0x4E4F534A: doc=json.loads(b[off:off+clen])
            off+=clen
        return doc
    return json.loads(p.read_text())
for a in sys.argv[1:]:
    p=pathlib.Path(a); doc=load(p)
    lo=[1e9]*3; hi=[-1e9]*3
    for m in doc.get('meshes',[]):
        for pr in m.get('primitives',[]):
            ai=pr['attributes'].get('POSITION')
            if ai is None: continue
            acc=doc['accessors'][ai]
            if 'min' in acc:
                for i in range(3):
                    lo[i]=min(lo[i],acc['min'][i]); hi[i]=max(hi[i],acc['max'][i])
    size=[round(hi[i]-lo[i],2) for i in range(3)]
    print(f"{p.name:32s} size={size}  min={[round(v,2) for v in lo]}")
