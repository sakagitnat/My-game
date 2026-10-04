#!/usr/bin/env python3
"""Tools for the outdoor ground (docs/ART_TOPDOWN.md, "Ground").
Run from the repo root.

  python3 tools/workshop/ground_tools.py check  TILE.png [TILE2.png ...]      seams of tiles + a 4x4 preview next to each (TILE_tiled.png)
  python3 tools/workshop/ground_tools.py seamless BIG.png NAME [--grid N] [--size 128] [--out DIR]
        makes a picture tile in every direction and cuts it to NAME_01.png (with --grid N: the picture is split into N x N
        parts, each made seamless, NAME_01 ... NAME_NN: variants of one ground)
  python3 tools/workshop/ground_tools.py edges  grass|dirt [--tiles DIR] [--out DIR]
        makes edge_<kind>_<n|e|s|w>_01.png and corner_<kind>_<ne|se|sw|nw>_01.png from tile_<kind>_01.png: the same ground,
        cut along a wavy line, transparent elsewhere (so it fits any ground below it)
  python3 tools/workshop/ground_tools.py map   [--tiles DIR] [--out map.png]   a preview map (grass, dirt, sand) with the edges laid over"""
import sys, os, math
from PIL import Image, ImageFilter
import numpy as np

TILES_DIR = 'assets/td/tiles'
S = 128                      # a tile is 128 px (one cell)
DEPTH = 0.42 * S             # how far an edge reaches into the cell (the game's BLEND_DEPTH)
arg = lambda name, default=None: sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default

def load(path):
    return Image.open(path).convert('RGBA')

def seam_scores(im):
    """(horizontal, vertical): how different the two edges that meet when the tile repeats are, compared with how different
    two neighbouring pixel rows normally are. About 1 = invisible seam; the higher, the more visible."""
    a = np.asarray(im.convert('RGB'), dtype=np.float32)
    def score(x):
        wrap = np.abs(x[:, 0] - x[:, -1]).mean()
        inner = np.abs(x[:, 1:] - x[:, :-1]).mean() + 1e-3
        return wrap / inner
    return score(a), score(a.transpose(1, 0, 2))

def tiled(im, n=4):
    out = Image.new('RGBA', (im.width * n, im.height * n))
    for y in range(n):
        for x in range(n):
            out.paste(im, (x * im.width, y * im.height))
    return out

def cmd_check():
    files = [a for a in sys.argv[2:] if not a.startswith('--')]
    for f in files:
        im = load(f)
        h, v = seam_scores(im)
        ok = h < 2.0 and v < 2.0 and im.size == (S, S)
        print(f"{'ok   ' if ok else 'check'} {f}: {im.width}x{im.height}, seam left-right {h:.1f}, top-bottom {v:.1f}"
              + ('' if im.size == (S, S) else f'  - size must be {S}x{S}')
              + ('' if h < 2.0 and v < 2.0 else '  - the edges do not match when the tile repeats: run "seamless" on it'))
        tiled(im).save(os.path.splitext(f)[0] + '_tiled.png')

def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)

def make_seamless(im):
    """Cross-fades the picture with itself shifted by half, once sideways and once down, so every edge matches its opposite."""
    a = np.asarray(im.convert('RGB'), dtype=np.float32)
    h, w = a.shape[:2]
    x = np.arange(w, dtype=np.float32)
    wx = smooth(1 - np.abs(x - w / 2) / (w / 2))   # 1 in the middle, 0 at the edges
    wx = wx[None, :, None]
    a = a * wx + np.roll(a, w // 2, axis=1) * (1 - wx)
    y = np.arange(h, dtype=np.float32)
    wy = smooth(1 - np.abs(y - h / 2) / (h / 2))[:, None, None]
    a = a * wy + np.roll(a, h // 2, axis=0) * (1 - wy)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGB').convert('RGBA')

def wrap_resize(im, size):
    """Resizes without breaking the repeat: resizes a 3x3 tiling and keeps the middle."""
    if im.size == (size, size):
        return im
    big = tiled(im, 3).resize((size * 3, size * 3), Image.LANCZOS)
    return big.crop((size, size, size * 2, size * 2))

def cmd_seamless():
    src, name = sys.argv[2], sys.argv[3]
    grid = int(arg('--grid', 1)); size = int(arg('--size', S)); out = arg('--out', TILES_DIR)
    im = load(src)
    side = min(im.size) // grid
    os.makedirs(out, exist_ok=True)
    n = 0
    for gy in range(grid):
        for gx in range(grid):
            n += 1
            part = im.crop((gx * side, gy * side, (gx + 1) * side, (gy + 1) * side))
            t = wrap_resize(make_seamless(part), size)
            path = f'{out}/{name}_{n:02d}.png'
            t.save(path)
            h, v = seam_scores(t)
            print(f'{path}: seam left-right {h:.1f}, top-bottom {v:.1f}')

# ---- edges ----------------------------------------------------------------------------------------------------------

def wobble(t, seed):
    """A smooth wavy value in -1..1 along t in 0..1; it is 0 at both ends and repeats (integer frequencies), so edge pieces of
    neighbouring cells meet where they end."""
    return (math.sin(2 * math.pi * 1 * t + seed) * 0.6 + math.sin(2 * math.pi * 2 * t + seed * 2.3) * 0.4) * math.sin(math.pi * t)

def edge_mask(side, seed=1.0, soft=5.0):
    """Alpha (S x S, 0..1) of the ground reaching into the cell from `side`, along a wavy line."""
    m = np.zeros((S, S), dtype=np.float32)
    for i in range(S):
        reach = DEPTH * (1 + 0.3 * wobble((i + 0.5) / S, seed))
        d = np.arange(S, dtype=np.float32) + 0.5
        col = np.clip((reach - d) / soft + 0.5, 0, 1)   # 1 near the side, fading out past `reach`
        if side == 'n': m[:, i] = col
        elif side == 's': m[:, i] = col[::-1]
        elif side == 'w': m[i, :] = col
        else: m[i, :] = col[::-1]
    return smoothed(m)

def smoothed(m):
    """A little blur so the wavy line has no sharp points (the blur keeps the alpha at the cell's own sides unchanged enough to meet the next cell)."""
    img = Image.fromarray((m * 255).astype(np.uint8), 'L').filter(ImageFilter.GaussianBlur(2.2))
    return np.asarray(img, dtype=np.float32) / 255

def corner_mask(corner, seed=2.0, soft=5.0):
    """Alpha of a blob of ground around one corner of the cell."""
    ys, xs = np.mgrid[0:S, 0:S].astype(np.float32) + 0.5
    cx = S if 'e' in corner else 0
    cy = S if 's' in corner else 0
    dx, dy = xs - cx, ys - cy
    dist = np.sqrt(dx * dx + dy * dy)
    theta = np.arctan2(np.abs(dy), np.abs(dx))   # 0..pi/2 inside the cell
    t = theta / (math.pi / 2)
    reach = DEPTH * (1 + 0.3 * (np.sin(2 * math.pi * 1 * t + seed) * 0.6 + np.sin(2 * math.pi * 2 * t + seed * 1.7) * 0.4) * np.sin(math.pi * t))
    return smoothed(np.clip((reach - dist) / soft + 0.5, 0, 1))

def piece(tile, mask):
    a = np.asarray(tile, dtype=np.float32).copy()
    a[..., 3] = a[..., 3] * mask
    return Image.fromarray(a.astype(np.uint8), 'RGBA')

def cmd_edges():
    kind = sys.argv[2]
    tiles = arg('--tiles', TILES_DIR); out = arg('--out', tiles)
    tile = load(f'{tiles}/tile_{kind}_01.png')
    assert tile.size == (S, S), f'tile_{kind}_01.png must be {S}x{S}'
    for side in 'nesw':
        piece(tile, edge_mask(side)).save(f'{out}/edge_{kind}_{side}_01.png')
    for corner in ('ne', 'se', 'sw', 'nw'):
        piece(tile, corner_mask(corner)).save(f'{out}/corner_{kind}_{corner}_01.png')
    print(f'edge_{kind}_* and corner_{kind}_* written to {out}')

# ---- preview map ----------------------------------------------------------------------------------------------------

MAP = ['gggggggggggg', 'ggddddgggggg', 'gdddddgggssg', 'gggdddgggsss', 'gggggggggsss', 'ggssgggggggg', 'gsssggddgggg', 'gggggggddggg']
RANK = {'s': 1, 'd': 2, 'g': 3}
NAME = {'d': 'dirt', 'g': 'grass'}

def cmd_map():
    tiles = arg('--tiles', TILES_DIR); out = arg('--out', 'ground_map.png')
    base = {'s': 'tile_sand_01', 'd': 'tile_dirt_01', 'g': 'tile_grass_01'}
    tex = {k: load(f'{tiles}/{v}.png') for k, v in base.items() if os.path.exists(f'{tiles}/{v}.png')}
    R, N = len(MAP), len(MAP[0])
    im = Image.new('RGBA', (N * S, R * S), (255, 0, 255, 255))
    kind = lambda x, y: MAP[y][x] if 0 <= x < N and 0 <= y < R else None
    for y in range(R):
        for x in range(N):
            if MAP[y][x] in tex:
                im.paste(tex[MAP[y][x]], (x * S, y * S))
    sides = {'n': (0, -1), 'e': (1, 0), 's': (0, 1), 'w': (-1, 0)}
    corners = {'ne': (1, -1), 'se': (1, 1), 'sw': (-1, 1), 'nw': (-1, -1)}
    for y in range(R):
        for x in range(N):
            mine = MAP[y][x]
            if mine == 'g':
                continue
            found = {}
            for s, (dx, dy) in sides.items():
                k = kind(x + dx, y + dy)
                if k and RANK[k] > RANK[mine]: found.setdefault(k, []).append(s)
            for c, (dx, dy) in corners.items():
                k = kind(x + dx, y + dy)
                if not k or RANK[k] <= RANK[mine] or kind(x + dx, y) == k or kind(x, y + dy) == k: continue
                found.setdefault(k, []).append(c)
            for k in sorted(found, key=lambda q: RANK[q]):
                for p in found[k]:
                    pre = 'edge' if p in sides else 'corner'
                    f = f'{tiles}/{pre}_{NAME[k]}_{p}_01.png'
                    if os.path.exists(f):
                        im.alpha_composite(load(f), (x * S, y * S))
    im.save(out)
    print('preview written to', out)

if __name__ == '__main__':
    cmds = {'check': cmd_check, 'seamless': cmd_seamless, 'edges': cmd_edges, 'map': cmd_map}
    if len(sys.argv) < 2 or sys.argv[1] not in cmds:
        print(__doc__); sys.exit(1)
    cmds[sys.argv[1]]()
