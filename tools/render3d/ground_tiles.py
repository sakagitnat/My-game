#!/usr/bin/env python3
"""Smooth painted ground tiles for the seaside set (128 x 128, repeat in every direction): grass, sand, dirt, road, stone terrace,
wooden shop floor, kitchen tiles. Painted at 4x and shrunk, so edges are soft; every shape that crosses an edge is drawn again on the
other side, so tiles join without seams. Then ground_tools.py cuts the soft grass and dirt edges from them.
python3 tools/render3d/ground_tiles.py [TILES_DIR]     (default assets/td/tiles)"""
import sys, os, math, random, subprocess
import numpy as np
from PIL import Image, ImageDraw

S = 128          # final size
K = 4            # painted this many times bigger
N = S * K
ROOT = os.path.join(os.path.dirname(__file__), '..', '..')

def hexc(s): return np.array([int(s[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float32)

def pnoise(seed, octaves=((2, 0.6), (4, 0.3), (8, 0.15), (16, 0.08))):
    """Noise that repeats over the tile: a sum of waves with whole-number frequencies. 0..1, N x N."""
    rnd = np.random.default_rng(seed)
    y, x = np.mgrid[0:N, 0:N].astype(np.float32) / N * 2 * np.pi
    out = np.zeros((N, N), np.float32)
    for f, amp in octaves:
        for _ in range(4):
            fx, fy = rnd.integers(-f, f + 1), rnd.integers(-f, f + 1)
            if fx == 0 and fy == 0: fx = f
            out += amp * np.cos(fx * x + fy * y + rnd.uniform(0, 2 * np.pi))
    out -= out.min(); out /= out.max()
    return out

def blend(a, b, t): return a[None, None, :] * (1 - t[..., None]) + b[None, None, :] * t[..., None]

def to_img(arr): return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGB')

def wrapped(draw_fn):
    """Calls draw_fn(dx, dy) for the tile and its 8 neighbours, so shapes crossing an edge reappear on the far side."""
    for dy in (-N, 0, N):
        for dx in (-N, 0, N): draw_fn(dx, dy)

def finish(im): return im.resize((S, S), Image.LANCZOS)

def grass(seed, flowers=0):
    n = pnoise(11)                                                   # one shared base for every variant: no checkerboard
    base = blend(hexc('#6aae40'), hexc('#84c44e'), n)            # between Terrain.GRASS_DARK and GRASS_LIGHT, so tiles and the shore blend agree
    im = to_img(base); d = ImageDraw.Draw(im)
    rnd = random.Random(seed)
    blades = [(rnd.uniform(0, N), rnd.uniform(0, N), rnd.uniform(14, 30), rnd.uniform(-0.5, 0.5), rnd.random()) for _ in range(110)]
    for x, y, h, lean, tone in blades:
        col = tuple(int(v) for v in (hexc('#5d9e3c') if tone < 0.45 else (hexc('#9ccf62') if tone > 0.85 else hexc('#7bbb4a'))))
        def blade(dx, dy, x=x, y=y, h=h, lean=lean, col=col):
            d.polygon([(x + dx - 3, y + dy), (x + dx + 3, y + dy), (x + dx + lean * h, y + dy - h)], fill=col)
        wrapped(blade)
    for _ in range(flowers):
        fx, fy = rnd.uniform(0, N), rnd.uniform(0, N); col = rnd.choice(['#fbf7ef', '#f3cd5a', '#ef8a8a'])
        def flower(dx, dy, fx=fx, fy=fy, col=col):
            for a in range(5):
                px, py = fx + dx + 7 * math.cos(a * 1.257), fy + dy + 7 * math.sin(a * 1.257)
                d.ellipse([px - 5, py - 5, px + 5, py + 5], fill=col)
            d.ellipse([fx + dx - 4, fy + dy - 4, fx + dx + 4, fy + dy + 4], fill='#e8a43a')
        wrapped(flower)
    return finish(im)

def sand(seed):
    n = pnoise(seed); fine = pnoise(seed + 1, ((24, 0.5), (40, 0.5)))
    y = np.mgrid[0:N, 0:N][0].astype(np.float32)
    ripple = 0.5 + 0.5 * np.sin(y / N * 2 * np.pi * 6 + n * 5)
    t = np.clip(n * 0.6 + fine * 0.25 + ripple * 0.15, 0, 1)
    im = to_img(blend(hexc('#ddc48c'), hexc('#efdcab'), t)); d = ImageDraw.Draw(im)   # Terrain.SAND_DARK .. SAND_LIGHT
    rnd = random.Random(seed)
    for _ in range(3):
        sx, sy = rnd.uniform(0, N), rnd.uniform(0, N)
        def shell(dx, dy, sx=sx, sy=sy):
            d.pieslice([sx + dx - 12, sy + dy - 10, sx + dx + 12, sy + dy + 12], 180, 360, fill='#fbefe4')
            d.pieslice([sx + dx - 8, sy + dy - 6, sx + dx + 8, sy + dy + 8], 180, 360, fill='#f2c6b4')
        wrapped(shell)
    return finish(im)

def dirt(seed, light=False):
    n = pnoise(seed); fine = pnoise(seed + 2, ((20, 0.5), (32, 0.5)))
    lo, hi = (hexc('#8a5f3c'), hexc('#b8875a')) if not light else (hexc('#b8915f'), hexc('#d8b483'))
    im = to_img(blend(lo, hi, np.clip(n * 0.7 + fine * 0.3, 0, 1))); d = ImageDraw.Draw(im)
    rnd = random.Random(seed)
    for _ in range(10):
        px, py, r = rnd.uniform(0, N), rnd.uniform(0, N), rnd.uniform(6, 13)
        def pebble(dx, dy, px=px, py=py, r=r):
            d.ellipse([px + dx - r, py + dy - r * 0.7 + 3, px + dx + r, py + dy + r * 0.7 + 3], fill='#6f4c32' if not light else '#a07c52')
            d.ellipse([px + dx - r, py + dy - r * 0.7, px + dx + r, py + dy + r * 0.7], fill='#b9ae9c')
            d.ellipse([px + dx - r * 0.6, py + dy - r * 0.6, px + dx + r * 0.2, py + dy], fill='#d8cfbf')
        wrapped(pebble)
    return finish(im)

def pavement(seed):
    """Sandstone flags in staggered rows with soft grout, each a little lighter at the top left."""
    im = Image.new('RGB', (N, N), '#9d917f'); d = ImageDraw.Draw(im)
    rnd = random.Random(seed)
    rows = [(0, 256), (256, 256)]
    for ri, (y0, h) in enumerate(rows):
        x = (ri * 150 + seed * 90) % N
        for w in ([280, 232] if ri % 2 == 0 else [236, 276]):
            tone = rnd.choice(['#d9ccb4', '#cfc1a7', '#e2d6c0', '#c8b99e'])
            def flag(dx, dy, x=x, y0=y0, w=w, h=h, tone=tone):
                d.rounded_rectangle([x + dx + 7, y0 + dy + 7, x + dx + w - 7, y0 + dy + h - 7], radius=22, fill='#b3a58f')
                d.rounded_rectangle([x + dx + 7, y0 + dy + 7, x + dx + w - 12, y0 + dy + h - 12], radius=22, fill=tone)
            wrapped(flag)
            x += w
    n = pnoise(seed + 9, ((6, 0.5), (16, 0.5)))
    arr = np.asarray(im, np.float32) * (0.94 + 0.08 * n[..., None])
    return finish(to_img(arr))

def boards(seed):
    """Warm wooden boards running across the shop, ends staggered, soft grain."""
    rnd = random.Random(seed)
    y, x = np.mgrid[0:N, 0:N].astype(np.float32)
    grain = pnoise(seed, ((1, 0.2), (2, 0.2), (24, 0.6)))
    arr = np.zeros((N, N, 3), np.float32)
    for r in range(2):
        tone = [hexc('#cf9058'), hexc('#d69a62')][(r + seed) % 2]
        band = (y >= r * 256) & (y < (r + 1) * 256)
        arr[band] = tone * (0.95 + 0.08 * grain[band][..., None])
    im = to_img(arr); d = ImageDraw.Draw(im)
    for r in range(2):
        y0 = r * 256
        d.rectangle([0, y0, N, y0 + 6], fill='#e2ad78')                       # lit top edge of the board
        d.rectangle([0, y0 + 248, N, y0 + 256], fill='#9a6640')               # gap
        if r == seed % 2:                                                     # one board end per cell
            ex = (seed * 211) % N
            def end(dx, dy, ex=ex, y0=y0):
                d.rectangle([ex + dx, y0 + dy, ex + dx + 6, y0 + dy + 250], fill='#9a6640')
                for ny in (60, 190): d.ellipse([ex + dx + 20, y0 + dy + ny, ex + dx + 28, y0 + dy + ny + 8], fill='#84552f')
            wrapped(end)
    return finish(im)

def kitchen():
    im = Image.new('RGB', (N, N), '#d8ccb8'); d = ImageDraw.Draw(im)
    for j in range(4):
        for i in range(4):
            col = '#fbf4e6' if (i + j) % 2 == 0 else '#6ea9d8'
            d.rounded_rectangle([i * 128 + 6, j * 128 + 6, i * 128 + 122, j * 128 + 122], radius=14, fill=col)
    return finish(im)

TILES = {
    'tile_grass_01': lambda: grass(11), 'tile_grass_02': lambda: grass(23, flowers=2), 'tile_grass_03': lambda: grass(37),
    'tile_dirt_01': lambda: dirt(9),   # no sand tile: the game's own smooth beach blend draws the sand, so the shore has no seams
    'tile_road_dirt_01': lambda: dirt(41, True), 'tile_road_dirt_02': lambda: dirt(43, True), 'tile_road_dirt_03': lambda: dirt(47, True),
    'tile_pavement_01': lambda: pavement(1), 'tile_pavement_02': lambda: pavement(2),
    'tile_floor_01': lambda: boards(1), 'tile_floor_02': lambda: boards(2), 'tile_floor_03': kitchen,
}

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'assets/td/tiles'
    os.makedirs(out, exist_ok=True)
    for name, fn in TILES.items():
        fn().save(os.path.join(out, name + '.png'))
    print('painted', len(TILES), 'tiles into', out)
    for kind in ('grass', 'dirt'):
        subprocess.run([sys.executable, os.path.join(ROOT, 'tools/workshop/ground_tools.py'), 'edges', kind, '--tiles', out, '--out', out], check=True)
