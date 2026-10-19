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
    W, H = 72, 54
    tiles = [['g'] * W for _ in range(H)]
    # a bay comes up to just below the shop; the land runs further out on both sides (woods on the headlands)
    def coast_y(x):
        left = smoothstep(14, 3, x)            # 0 in the bay, 1 at the far left
        right = smoothstep(30, 42, x)
        return 26.5 + 14.0 * left + 13.5 * right + 1.6 * (value(x * 0.13, 3.0, 51) - 0.5) + 0.7 * (value(x * 0.5, 7.0, 53) - 0.5)
    coast = [coast_y(x) for x in range(W)]
    for y in range(H):
        for x in range(W):
            if y > coast[x]:
                tiles[y][x] = 'w'
    near = near_water(tiles, W, H, 3)          # a wide beach
    for y in range(H):
        for x in range(W):
            if tiles[y][x] == 'g' and (x, y) in near:
                tiles[y][x] = 's'
    # the country road runs across the top (back) edge of the map, flush to the border
    for y in range(0, 4):
        for x in range(W):
            tiles[y][x] = 'r'
    # a paved path from the road to the door
    for y in range(4, 6):
        for x in range(16, 20):
            tiles[y][x] = 'p'
    # the shop: 12 x 12 cells of tiled floor near the back-left corner, door in the north wall facing the road
    X0, Y0, X1, Y1 = 12, 6, 24, 18   # [X0, X1) x [Y0, Y1)
    for y in range(Y0, Y1):
        for x in range(X0, X1):
            tiles[y][x] = 'f'
    # a stone terrace in front of the shop, looking over the beach, with steps down to the sand
    for y in range(Y1, Y1 + 3):
        for x in range(X0 - 1, X1 + 1):
            if tiles[y][x] == 'g':
                tiles[y][x] = 'p'
    for y in range(Y1 + 3, Y1 + 6):
        for x in range(16, 20):
            if tiles[y][x] == 'g':
                tiles[y][x] = 'p'
    # the garden path: from the road, down between the shop and the kitchen garden, to the terrace
    for y in range(4, Y1):
        for x in range(26, 28):
            tiles[y][x] = 'd'
    walls = []
    for x in range(X0, X1):
        kind = "door" if x in (17, 18) else ("window" if x in (13, 14, 21, 22) else "wall")
        walls.append([x, Y0, "n", kind])
    for y in range(Y0, Y1):
        walls.append([X0, y, "w", "window" if y in (8, 9, 14, 15) else "wall"])
    for y in range(Y0, Y1):
        walls.append([X1, y, "w", "low"])
    for x in range(X0, X1):
        walls.append([x, Y1, "n", "low"])
    # shop blocks (S at columns 2-3), the kitchen garden next to it (S at columns 5-6, the garden path between them);
    # land for sale (B) where there is land, nothing out at sea
    def land_share(px, py):
        cells = [(x, y) for y in range(py * 6, py * 6 + 6) for x in range(px * 6, px * 6 + 6)]
        return sum(1 for (x, y) in cells if tiles[y][x] not in 'wr') / len(cells)
    def centre_dry(px, py):                    # the game puts the sale sign in the middle of the block, so the middle must be dry
        cx, cy = px * 6 + 3, py * 6 + 3
        return all(tiles[y][x] != 'w' for y in range(cy - 1, cy + 2) for x in range(cx - 1, cx + 2))
    START = {(2, 1), (3, 1), (2, 2), (3, 2), (5, 1), (6, 1), (5, 2), (6, 2)}
    parcels = ["".join('S' if (px, py) in START else 'B' if 1 <= px <= 10 and py >= 1 and land_share(px, py) > 0.6 and centre_dry(px, py) else '.'
                       for px in range(W // 6)) for py in range(H // 6)]
    protected = set()
    for py, row in enumerate(parcels):
        for px, ch in enumerate(row):
            if ch == 'S':
                for y in range(py * 6 + 1, py * 6 + 5):
                    for x in range(px * 6 + 1, px * 6 + 5):
                        protected.add((x, y))
    shore = near_water(tiles, W, H, 4)
    def dens(x, y):
        if (x, y) in shore or y < 6:
            return (0, 0)
        px, py = x // 6, y // 6
        ch = parcels[py][px]
        if px < 1 or px > 9:                       # woods on the headlands and down the edges
            return (2.0, 0.55)
        if 1 <= px <= 7 and py <= 3:               # around the shop and the garden: a few trees to clear, not a wood
            return (0.35, 0.02)
        if py >= 4:                                # the wooded headlands either side of the bay
            return (1.6, 0.45)
        if ch == 'B':
            return (0.9, 0.08)                     # open land waiting to be bought and cleared
        return (0.4, 0.08)
    obstacles = scatter(W, H, tiles, parcels, 20261002, dens, protected)
    obstacles = [o for o in obstacles if tiles[o[1]][o[0]] in 'g']
    return {"version": 1, "id": "restaurant", "area": "any", "size": [W, H],
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
