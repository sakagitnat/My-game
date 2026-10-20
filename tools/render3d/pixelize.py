#!/usr/bin/env python3
"""Turns the 3D renders (render.py, SS times the final size) into Salvora pixel art: shrink to 32 px per cell, every pixel fully opaque or fully
clear, every colour snapped to the shared palette (tools/pixelart/palette.py), then a selective outline (each edge pixel takes the darkest
colour of its own family, as the hand-drawn pieces do).
python3 tools/render3d/pixelize.py RAWDIR [OUTDIR]     (default OUTDIR assets/td/art_workshop/pilot/render3d)"""
import sys, os, glob
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'pixelart'))
from PIL import Image
from palette import P, T

SS = 8
WOOD = ['w0', 'w1', 'w2', 'w3', 'w4', 'w5', 'w6']
# Colours each piece may use: a small set per piece keeps the shading in the right family (wood stays wood).
FAMILIES = {
    'rest_table': WOOD, 'chair': WOOD,
    'rest_stove': ['c0', 'c1', 'c2', 'c3', 'c4', 'n0', 'n1', 's0', 's1', 's2', 's3', 'b0', 'b1', 'b2', 'b3', 'b4', 'r0', 'r1', 'r2'],
    'cook': ['k0', 'k1', 'k2', 'h0', 'h1', 'h2', 'e0', 'b0', 'b1', 'b2', 'b3', 'b4', 'c1', 'c2', 'c3', 'c4', 'w0', 'w1', 'w2', 'p0', 'p1'],
}
# The darkest colour of each family, used for its outline.
EDGE = {'w': 'w1', 'c': 'n0', 'n': 'n0', 's': 's0', 'b': 'b0', 'r': 'r0', 'k': 'k0', 'h': 'h0', 'e': 'e0', 'p': 'p0', 'l': 'l0', 'g': 'g0', 'y': 'r0'}

def dist(a, b):
    """Weighted RGB distance ("redmean"), close enough to how eyes compare colours for a small palette."""
    r = (a[0] + b[0]) / 2
    dr, dg, db = a[0] - b[0], a[1] - b[1], a[2] - b[2]
    return (2 + r / 256) * dr * dr + 4 * dg * dg + (2 + (255 - r) / 256) * db * db

def keys_for(name):
    for prefix, keys in FAMILIES.items():
        if name.startswith(prefix): return keys
    return list(P)

def pixelize(raw, name):
    w, h = raw.width // SS, raw.height // SS
    small = raw.convert('RGBa').resize((w, h), Image.BOX).convert('RGBA')              # premultiplied, so clear edges do not darken colours
    keys = keys_for(name)
    out = Image.new('RGBA', (w, h), T)
    key_at = {}
    cache = {}
    for y in range(h):
        for x in range(w):
            c = small.getpixel((x, y))
            if c[3] < 128: continue
            rgb = c[:3]
            if rgb not in cache: cache[rgb] = min(keys, key=lambda k: dist(rgb, P[k]))
            k = cache[rgb]; key_at[(x, y)] = k; out.putpixel((x, y), P[k])
    for (x, y), k in key_at.items():                                                     # selective outline on the silhouette
        if any((x + dx, y + dy) not in key_at for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            out.putpixel((x, y), P[EDGE.get(k[0], 'out')])
    return out

if __name__ == '__main__':
    raw_dir = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else 'assets/td/art_workshop/pilot/render3d'
    os.makedirs(out_dir, exist_ok=True)
    for f in sorted(glob.glob(os.path.join(raw_dir, '*.png'))):
        name = os.path.splitext(os.path.basename(f))[0]
        im = pixelize(Image.open(f), name)
        im.save(os.path.join(out_dir, name + '.png')); print(name, im.size)
