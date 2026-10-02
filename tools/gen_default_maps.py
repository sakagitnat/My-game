#!/usr/bin/env python3
"""Writes the starting maps in data/maps/. Run once to regenerate the defaults; the game reads the JSON.
Tiles: g grass, s sand, w water, r dirt road, p pavement, f indoor floor, d bare dirt.
Walls: [x, y, edge, kind] edge "n" = north face of cell (x, y) (between y-1 and y), "w" = west face (between x-1 and x);
kind: wall, window, door, low. Parcels: one char per 6x6 block: . locked, B for sale, S owned from the start."""
import json, math, sys

def hash2(x, y, seed):
    M = 0x7fffffff
    h = (x * 374761393 + y * 668265263 + seed * 1442695041) & M
    h = ((h ^ (h >> 13)) * 1274126177) & M
    h = h ^ (h >> 16)
    return (h & 0xffff) / 65535.0

def value(x, y, seed):
    xi = math.floor(x); yi = math.floor(y); fx = x - xi; fy = y - yi
    u = fx * fx * (3 - 2 * fx); v = fy * fy * (3 - 2 * fy)
    a = hash2(xi, yi, seed); b = hash2(xi + 1, yi, seed); c = hash2(xi, yi + 1, seed); d = hash2(xi + 1, yi + 1, seed)
    return (a + (b - a) * u) * (1 - v) + (c + (d - c) * u) * v

def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)

def scatter(W, H, tiles, parcels, seed, density_fn, protected):
    out = []
    for y in range(H):
        for x in range(W):
            if tiles[y][x] not in 'gd' or (x, y) in protected:
                continue
            dens, forest = density_fn(x, y)
            if dens <= 0 and forest <= 0:
                continue
            f = smoothstep(0.5, 0.78, value(x * 0.2, y * 0.2, seed))
            chance = (0.02 + 0.04) * dens + forest * f
            if hash2(x, y, seed + 1) >= chance:
                continue
            r = hash2(x, y, seed + 2)
            out.append([x, y, "tree" if r < 0.55 else ("rock" if r < 0.82 else "bush")])
    return out

def near_water(tiles, W, H, r):
    water = [(x, y) for y in range(H) for x in range(W) if tiles[y][x] == 'w']
    near = set()
    for (wx, wy) in water:
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                near.add((wx + dx, wy + dy))
    return near

def restaurant():
    W, H = 48, 36
    tiles = [['g'] * W for _ in range(H)]
    coast = [6.5 + 2.2 * (value(x * 0.13, 3.0, 51) - 0.5) + 0.8 * (value(x * 0.5, 7.0, 53) - 0.5) for x in range(W)]
    for y in range(H):
        for x in range(W):
            if y < coast[x]:
                tiles[y][x] = 'w'
    near = near_water(tiles, W, H, 2)
    for y in range(H):
        for x in range(W):
            if tiles[y][x] == 'g' and (x, y) in near:
                tiles[y][x] = 's'
    for y in range(25, 29):
        for x in range(W):
            tiles[y][x] = 'r'
    for x in range(17, 31):
        tiles[24][x] = 'p'
    for y in range(12, 24):
        for x in range(18, 30):
            tiles[y][x] = 'f'
    walls = []
    wins_n = {19, 20, 23, 24, 27, 28}
    for x in range(18, 30):
        walls.append([x, 12, "n", "window" if x in wins_n else "wall"])
    for y in range(12, 24):
        walls.append([18, y, "w", "window" if y in (15, 16, 19, 20) else "wall"])
    for x in range(18, 30):
        walls.append([x, 24, "n", "door" if x in (23, 24) else "low"])
    for y in range(12, 24):
        walls.append([30, y, "w", "low"])
    parcels = ["........", "..BBBB..", ".BBSSBB.", ".BBSSBB.", "........", "........"]
    protected = set()
    for py, row in enumerate(parcels):
        for px, ch in enumerate(row):
            if ch == 'S':
                for y in range(py * 6 + 1, py * 6 + 5):
                    for x in range(px * 6 + 1, px * 6 + 5):
                        protected.add((x, y))
    for y in range(H):
        for x in range(W):
            if (x, y) in near_water(tiles, W, H, 0) if False else False:
                pass
    shore = near_water(tiles, W, H, 3)
    def dens(x, y):
        if (x, y) in shore:
            return (0, 0)
        px, py = x // 6, y // 6
        ch = parcels[py][px]
        if py == 5 or px < 1 or px > 6:           # woods around the edge
            return (3.0, 0.85)
        if ch == 'B':
            return (1.6, 0.2)
        return (0, 0)
    obstacles = scatter(W, H, tiles, parcels, 20261002, dens, protected)
    return {"version": 1, "id": "restaurant", "area": "restaurant", "size": [W, H],
            "tiles": ["".join(r) for r in tiles], "walls": walls, "obstacles": obstacles, "objects": [],
            "parcels": parcels, "exits": []}

def farm():
    W = H = 30
    tiles = [['g'] * W for _ in range(H)]
    parcels = ["BBBBB", "BBBBB", "BBSBB", "BBBBB", "BBBBB"]
    protected = set()
    for y in range(13, 17):
        for x in range(13, 17):
            protected.add((x, y))
    def dens(x, y):
        return (1.0, 0.3)
    obstacles = scatter(W, H, tiles, parcels, 20261002 + 7919, dens, protected)
    return {"version": 1, "id": "farm", "area": "farm", "size": [W, H],
            "tiles": ["".join(r) for r in tiles], "walls": [], "obstacles": obstacles, "objects": [],
            "parcels": parcels, "exits": []}

def dump(d, path):
    # one line per list entry so diffs and pasted maps stay readable
    s = json.dumps(d, ensure_ascii=False, separators=(",", ":"))
    open(path, "w").write(s + "\n")

if __name__ == "__main__":
    dump(restaurant(), "data/maps/restaurant.json")
    dump(farm(), "data/maps/farm.json")
    print("written")
