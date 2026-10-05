#!/usr/bin/env python3
"""Pixel art (32 px per cell) drawn by code: the first batch for the restaurant (pilot).
python3 tools/pixelart/shop_pilot.py [OUTDIR]     writes one PNG per piece (real pixel size) and a 4x contact sheet."""
import sys, os, random
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
from palette import P, T

class Pix:
    def __init__(self, w, h):
        self.im = Image.new('RGBA', (w, h), T); self.w, self.h = w, h
    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h: self.im.putpixel((x, y), P[c] if isinstance(c, str) else c)
    def rect(self, x0, y0, x1, y1, c):          # inclusive corners
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1): self.set(x, y, c)
    def hline(self, x0, x1, y, c): self.rect(x0, y, x1, y, c)
    def vline(self, x, y0, y1, c): self.rect(x, y0, x, y1, c)
    def disc(self, cx, cy, r, c):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r: self.set(x, y, c)
    def ring(self, cx, cy, r0, r1, c):
        for y in range(int(cy - r1) - 1, int(cy + r1) + 2):
            for x in range(int(cx - r1) - 1, int(cx + r1) + 2):
                d = (x - cx) ** 2 + (y - cy) ** 2
                if r0 * r0 < d <= r1 * r1: self.set(x, y, c)
    def get(self, x, y): return self.im.getpixel((x, y))

# ---------- floors (seamless: everything repeats every 32 px) ----------
def floor(tones, seed, joint='w0'):
    p = Pix(32, 32); rnd = random.Random(seed)
    joints = [[11], [27], [5, 21], [16]] if seed == 1 else [[19], [3, 19], [10], [26]]
    for row in range(4):
        y0 = row * 8
        xs = sorted(joints[row]); n = len(xs)
        for k in range(n):
            a = xs[k] + 1; b = xs[(k + 1) % n] + (32 if k == n - 1 else 0)   # a plank runs from one joint to the next (wrapping)
            tone = tones[(row * 2 + k + seed) % len(tones)]
            for x in range(a, b + 1):
                xm = x % 32
                p.rect(xm, y0, xm, y0 + 6, tone[1])
                p.set(xm, y0, tone[0])               # light top edge
                p.set(xm, y0 + 7, tone[2])           # dark seam below
            # grain: short dark dashes
            for _ in range(1):
                gx = rnd.randint(a, b - 4); gy = y0 + rnd.randint(2, 5)
                for d in range(rnd.randint(3, 5)): p.set((gx + d) % 32, gy, tone[2] if rnd.random() < 0.3 else tone[1])
        for j in xs:                                  # plank joint with two nails
            p.vline(j, y0, y0 + 7, joint)
    return p.im

# pale driftwood boards (a whitewashed seaside floor): light, so the warm wood furniture stands out from it
def floor_a(): return floor([('c4', 'c3', 'c2'), ('c4', 'c3', 'c1'), ('c4', 'c2', 'c1')], 1, 'c2')
def floor_b(): return floor([('c3', 'c2', 'c1'), ('c3', 'c2', 'c0'), ('c2', 'c2', 'c1')], 2, 'c2')

# ---------- walls ----------
def planks(p, x0, x1, y0, y1, a, b, hi, seam, w=8):
    for x in range(x0, x1 + 1):
        i = (x // w)
        col = a if i % 2 == 0 else b
        for y in range(y0, y1 + 1): p.set(x, y, col)
        if x % w == 0: p.vline(x, y0, y1, seam)
        if x % w == 1: p.vline(x, y0, y1, hi)

def panel(p, x0, x1, y0, y1):
    """A blue wainscot panel set into a cream frame: the inside is darker than the frame, shaded along its top and left (it is recessed),
    and every 32 px a cream stile frames it, so the frame runs all round each panel."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): p.set(x, y, 'b1')
    for x in range(x0 + 2, x1 - 1):                                                            # vertical boards inside, darker than before
        if (x - x0) % 8 in (3, 4): p.vline(x, y0 + 3, y1 - 2, 'b0')
        elif (x - x0) % 8 == 5: p.vline(x, y0 + 3, y1 - 2, 'b2')
    p.hline(x0, x1, y0, 'n0'); p.hline(x0, x1, y0 + 1, 'b0'); p.hline(x0, x1, y0 + 2, 'b0')   # shadow under the top rail
    p.vline(x0, y0, y1, 'c3'); p.vline(x0 + 1, y0, y1, 'n1'); p.vline(x1, y0, y1, 'n0'); p.vline(x1 - 1, y0, y1, 'c4')   # stiles of the frame
    p.hline(x0 + 2, x1 - 2, y1 - 1, 'b2')                                                      # lit lower edge inside

def wall_plain():
    p = Pix(32, 96)
    planks(p, 0, 31, 4, 59, 'c1', 'c1', 'c2', 'c0')
    rnd = random.Random(7)
    for _ in range(14):                                           # wood flecks
        x = rnd.randint(0, 31); y = rnd.randint(6, 56)
        if x % 8 not in (0, 1): p.vline(x, y, y + rnd.randint(1, 3), 'c0')
    p.rect(0, 0, 31, 3, 'c3'); p.hline(0, 31, 0, 'c4'); p.hline(0, 31, 3, 'n1')               # top trim
    p.rect(0, 60, 31, 63, 'c3'); p.hline(0, 31, 60, 'c4'); p.hline(0, 31, 63, 'n0')            # chair rail
    panel(p, 0, 31, 64, 91)                                                                    # framed, recessed blue panel
    p.rect(0, 92, 31, 95, 'c3'); p.hline(0, 31, 92, 'c4'); p.hline(0, 31, 95, 'n0')           # skirting
    return p.im

def wall_low():
    p = Pix(32, 16)
    p.rect(0, 0, 31, 3, 'c3'); p.hline(0, 31, 0, 'c4'); p.hline(0, 31, 3, 'n0')
    planks(p, 0, 31, 4, 13, 'b2', 'b3', 'b4', 'b0')
    p.rect(0, 14, 31, 15, 'c3'); p.hline(0, 31, 15, 'n0')
    return p.im

def wall_side():
    """Seen from the side: a thick post (12 px = 24 in game) with a grey-white outline on both edges. The game stacks it a cell at a time and draws the cap
    itself, so the top 32 px repeat: nothing across them. The bottom shows the end of the wall: rail, recessed blue panel, skirting."""
    W = 12
    p = Pix(W, 96)
    for y in range(96):
        p.set(0, y, 'n0'); p.set(1, y, 'c2'); p.rect(2, y, W - 4, y, 'c1'); p.set(W - 3, y, 'c0'); p.set(W - 2, y, 'c0'); p.set(W - 1, y, 'n0')
    p.rect(0, 60, W - 1, 63, 'c3'); p.hline(0, W - 1, 60, 'c4'); p.hline(0, W - 1, 63, 'n0'); p.set(0, 60, 'n0'); p.set(W - 1, 60, 'n0')   # chair rail
    for y in range(64, 92):                                                                     # blue panel set into the post, darker than the frame
        p.set(0, y, 'n0'); p.set(1, y, 'c4'); p.rect(2, y, W - 3, y, 'b1'); p.set(W - 2, y, 'c2'); p.set(W - 1, y, 'n0')
        if y > 66:
            for x in (4, 7): p.set(x, y, 'b0')
            for x in (5, 8): p.set(x, y, 'b2')
    p.rect(2, 64, W - 3, 66, 'b0')                                                              # shadow under the rail
    p.rect(0, 92, W - 1, 95, 'c3'); p.hline(0, W - 1, 92, 'c4'); p.hline(0, W - 1, 95, 'n0'); p.set(0, 92, 'n0'); p.set(W - 1, 92, 'n0')   # skirting
    return p.im

# ---------- door and window (overlays on a wall; the last 6 rows hang below the base line) ----------
def door():
    p = Pix(32, 70)
    p.rect(0, 0, 31, 63, 'w2')                                                     # frame
    p.hline(0, 31, 0, 'w5'); p.hline(0, 31, 1, 'w4'); p.hline(0, 31, 3, 'w1')
    p.vline(0, 0, 63, 'w4'); p.vline(1, 0, 63, 'w3'); p.vline(31, 0, 63, 'w1'); p.vline(30, 0, 63, 'w1'); p.vline(2, 4, 63, 'w1')
    p.rect(3, 4, 28, 63, 'b2')                                                     # leaf
    for x in range(3, 29, 6):                                                      # planks
        p.vline(x, 4, 63, 'b0'); p.vline(x + 1, 4, 63, 'b3')
    p.rect(3, 4, 28, 5, 'b1'); p.hline(3, 28, 4, 'b4')                           # top rail
    p.rect(8, 33, 23, 56, 'b1'); p.rect(9, 34, 22, 55, 'b2')                       # lower panel
    p.hline(8, 23, 33, 'b0'); p.vline(8, 33, 56, 'b0'); p.hline(8, 23, 56, 'b3'); p.vline(23, 33, 56, 'b3')
    p.disc(15.5, 18, 6.5, 'r1'); p.disc(15.5, 18, 5, 'r0'); p.disc(15.5, 18, 4, 'g1')   # porthole
    p.rect(12, 15, 13, 16, 'g2'); p.hline(17, 19, 21, 'g0'); p.ring(15.5, 18, 4, 5, 'r1')
    p.set(11, 12, 'r2'); p.set(20, 12, 'r2')
    p.rect(24, 30, 26, 36, 'r0'); p.rect(24, 30, 25, 35, 'r1'); p.set(24, 30, 'r2')    # handle
    p.rect(3, 60, 28, 63, 'b1'); p.hline(3, 28, 63, 'b0')                           # kick plate
    p.rect(1, 64, 30, 66, 'c1'); p.hline(1, 30, 64, 'c3'); p.hline(1, 30, 66, 'c0')   # threshold stone
    return p.im

def door_open():
    """The same door swung open into the room: the frame stays, the opening shows the dim room and its floor, the leaf is seen edge-on at the hinge side,
    narrow and a little shorter at its far edge (perspective)."""
    p = Pix(32, 70)
    p.rect(0, 0, 31, 63, 'w2')
    p.hline(0, 31, 0, 'w5'); p.hline(0, 31, 1, 'w4'); p.hline(0, 31, 3, 'w1')
    p.vline(0, 0, 63, 'w4'); p.vline(1, 0, 63, 'w3'); p.vline(31, 0, 63, 'w1'); p.vline(30, 0, 63, 'w1'); p.vline(2, 4, 63, 'w1')
    p.rect(3, 4, 28, 63, 'w0')                                                    # the dim room behind
    p.rect(3, 4, 28, 20, 'w1'); p.rect(3, 21, 28, 26, 'w0')
    p.rect(3, 50, 28, 63, 'c1'); p.hline(3, 28, 50, 'c0'); p.rect(3, 56, 28, 63, 'c2')   # the floor inside, lighter near the door
    for x in range(3, 29, 8): p.vline(x, 50, 63, 'c0')
    for x in range(3, 12):                                                         # the leaf, hinged on the left: its far edge is shorter
        t = (x - 3) / 8.0
        top = 4 + int(round(4 * t)); bot = 63 - int(round(5 * t))
        for y in range(top, bot + 1): p.set(x, y, 'b2' if x % 4 else 'b0')
        p.set(x, top, 'b4'); p.set(x, bot, 'b0')
    p.vline(11, 8, 58, 'b0'); p.vline(10, 9, 57, 'b3')
    p.disc(7, 18, 2, 'r1'); p.set(7, 18, 'g1')                                      # porthole, foreshortened
    p.rect(9, 33, 9, 37, 'r0'); p.set(9, 33, 'r2')                                  # handle
    p.rect(3, 12, 4, 14, 'r0'); p.rect(3, 48, 4, 50, 'r0')                          # hinges
    p.rect(1, 64, 30, 66, 'c1'); p.hline(1, 30, 64, 'c3'); p.hline(1, 30, 66, 'c0')   # threshold stone
    return p.im

def window():
    p = Pix(32, 32)
    p.rect(3, 2, 28, 25, 'c3')                                                     # white frame
    p.hline(3, 28, 2, 'c4'); p.vline(3, 2, 25, 'c4'); p.hline(3, 28, 25, 'n0'); p.vline(28, 2, 25, 'n0')
    for (gx0, gy0) in ((5, 4), (16, 4), (5, 14), (16, 14)):                         # four panes
        for y in range(gy0, gy0 + 10 if gy0 == 4 else gy0 + 9):
            for x in range(gx0, gx0 + 9):
                t = (y - gy0) / 10.0
                p.set(x, y, 'g2' if t < 0.25 else 'g1' if t < 0.65 else 'g0')
        p.hline(gx0, gx0 + 8, gy0, 'g0'); p.vline(gx0, gy0, gy0 + 8, 'g0')
        for d in range(4): p.set(gx0 + 6 - d, gy0 + 1 + d, 'c4')                   # glint
    p.rect(14, 3, 15, 24, 'c3'); p.rect(4, 12, 27, 13, 'c3'); p.vline(14, 3, 24, 'c4'); p.hline(4, 27, 12, 'c4')
    p.rect(1, 26, 30, 28, 'c2'); p.hline(1, 30, 26, 'c4'); p.hline(1, 30, 28, 'n1')   # sill
    p.hline(2, 29, 29, 'n0')
    return p.im

# ---------- table and stove (2 x 2 cells: top surface seen from above on the upper half, the front on the lower half) ----------
def table():
    """64 x 48: two cells wide, one deep, about waist high (well below a person): the top seen from above in the top 16 rows, the front edge and legs below."""
    p = Pix(64, 48)
    p.rect(0, 0, 63, 15, 'w4')
    for r in range(2):                                                             # planks run along the width
        y = r * 8; tone = ('w4', 'w5')[r]
        p.rect(1, y + 1, 62, y + 6, tone); p.hline(1, 62, y + 7, 'w2'); p.hline(1, 62, y, 'w6' if r == 0 else 'w5')
    rnd = random.Random(3)
    for r in range(2):
        for _ in range(2):
            x = rnd.randint(3, 50); p.hline(x, x + rnd.randint(3, 8), r * 8 + rnd.randint(2, 5), 'w3')
    for j, y in ((22, 0), (44, 8)): p.vline(j, y + 1, y + 7, 'w1')                 # plank joints
    p.hline(0, 63, 0, 'w1'); p.vline(0, 0, 15, 'w1'); p.vline(63, 0, 15, 'w1'); p.rect(1, 1, 62, 1, 'w6')
    p.rect(0, 16, 63, 20, 'w2'); p.hline(0, 63, 16, 'w5'); p.hline(0, 63, 20, 'w1')   # front thickness
    for lx in (3, 54):                                                             # legs
        p.rect(lx, 21, lx + 6, 47, 'w2'); p.vline(lx, 21, 47, 'w4'); p.vline(lx + 1, 21, 47, 'w3'); p.vline(lx + 6, 21, 47, 'w1')
        p.rect(lx, 46, lx + 6, 47, 'w0')
    p.rect(10, 36, 53, 38, 'w2'); p.hline(10, 53, 36, 'w3'); p.hline(10, 53, 38, 'w1')   # stretcher
    p.set(0, 47, T); p.set(63, 47, T)
    return p.im

def stove():
    """64 x 56: two cells wide, one deep, a block tall (32 rows of front + 16 of top) and 8 rows of back splash standing against the wall.
    The bottom 48 rows are the footprint, the top 8 rows overlap the wall a little."""
    p = Pix(64, 56)
    p.rect(1, 1, 62, 7, 'c2'); p.hline(1, 62, 1, 'c3')                                         # back splash (tiles), overlaps the wall
    for x in range(1, 63, 8): p.vline(x, 2, 7, 'c1')
    p.hline(1, 62, 7, 'n0')
    p.rect(0, 8, 63, 23, 'c2'); p.hline(0, 63, 8, 'c4'); p.vline(0, 8, 23, 'c3'); p.vline(63, 8, 23, 'n1')   # top surface seen from above
    p.rect(3, 10, 60, 22, 's0'); p.hline(3, 60, 10, 's1')
    for cx in (18, 45):                                                                         # two burners
        p.disc(cx, 16, 5, 's1'); p.disc(cx, 16, 4, 's0'); p.ring(cx, 16, 2, 3, 's2'); p.set(cx, 16, 's1')
        p.hline(cx - 5, cx + 5, 16, 's1'); p.vline(cx, 11, 21, 's1')
    p.rect(0, 24, 63, 28, 'c3'); p.hline(0, 63, 24, 'c4'); p.hline(0, 63, 28, 'n1')            # front panel with knobs
    for kx in (10, 20, 43, 53):
        p.disc(kx, 26, 1.6, 'r1'); p.set(kx - 1, 25, 'r2')
    p.rect(0, 29, 63, 55, 'c2'); p.vline(0, 29, 55, 'c3'); p.vline(63, 29, 55, 'n1')           # body
    p.rect(5, 31, 58, 51, 'b1'); p.hline(5, 58, 31, 'b4'); p.vline(5, 31, 51, 'b3'); p.hline(5, 58, 51, 'b0'); p.vline(58, 31, 51, 'b0')   # oven door frame
    p.rect(9, 36, 54, 48, 's0'); p.hline(9, 54, 36, 's1'); p.rect(11, 38, 20, 39, 's1'); p.hline(11, 17, 38, 's2')   # oven window
    p.rect(8, 33, 55, 34, 'r1'); p.hline(8, 55, 33, 'r2'); p.hline(8, 55, 34, 'r0')           # handle
    p.rect(0, 53, 63, 55, 'n1'); p.hline(0, 63, 55, 'n0')
    p.hline(0, 63, 0, 'n0'); p.vline(0, 0, 55, 'n0'); p.vline(63, 0, 55, 'n0')
    return p.im

# ---------- vases ----------
def autoline(p, c):
    """Outline: every empty pixel that touches the shape (up, down, left, right) gets colour c."""
    mark = []
    for y in range(p.h):
        for x in range(p.w):
            if p.get(x, y)[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < p.w and 0 <= ny < p.h and p.get(nx, ny)[3] > 0: mark.append((x, y)); break
    for x, y in mark: p.set(x, y, c)

def vase_shape(p, cx, rows, light, mid, dark, pattern=None):
    """rows: (y, half width) from the top; cx the centre column (the shape spans cx-half .. cx+half-1)."""
    for y, half in rows:
        for x in range(cx - half, cx + half):
            edge = x - (cx - half); inner = (cx + half - 1) - x
            p.set(x, y, light if edge <= 1 else dark if inner <= 1 else mid)
    return p

def vase_small():
    p = Pix(16, 16)
    rows = [(4, 3), (5, 2), (6, 2), (7, 3), (8, 4), (9, 5), (10, 5), (11, 5), (12, 4), (13, 4), (14, 3)]
    vase_shape(p, 8, rows, 'c4', 'c3', 'c1')
    for x in range(4, 12): p.set(x, 10 + (1 if x % 4 in (1, 2) else 0), 'b2')                  # blue wave band
    p.hline(6, 9, 4, 'c2')
    autoline(p, 'n0')
    for x, y, c in ((7, 1, 'p1'), (8, 0, 'p1'), (10, 1, 'y0'), (5, 2, 'p1'), (6, 3, 'l1'), (9, 3, 'l1'), (7, 2, 'l1'), (8, 2, 'l2')): p.set(x, y, c)
    return p.im

def vase_large():
    p = Pix(32, 32)
    rows = [(9, 6), (10, 4), (11, 4), (12, 4), (13, 5), (14, 7), (15, 9), (16, 10), (17, 11), (18, 11), (19, 11), (20, 11), (21, 11), (22, 10),
            (23, 10), (24, 9), (25, 8), (26, 7), (27, 7), (28, 7), (29, 6)]
    vase_shape(p, 16, rows, 'c4', 'c3', 'c1')
    for (y, half) in rows:                                                                       # two wavy blue bands that follow the belly
        if y in (18, 19, 23, 24):
            for x in range(16 - half + 2, 16 + half - 2):
                wave = 1 if x % 6 in (1, 2, 3) else 0
                if (y in (18, 24) and wave == 0) or (y in (19, 23) and wave == 1): p.set(x, y, 'b2' if y in (18, 19) else 'b3')
    p.hline(10, 21, 9, 'c2')
    autoline(p, 'n0')
    stems = ((14, 3, 8, 'p1'), (18, 2, 8, 'y0'), (11, 5, 8, 'p1'), (21, 5, 9, 'p0'))
    for fx, fy, ey, col in stems:
        p.vline(fx, fy + 2, ey, 'l1')
        p.disc(fx, fy, 1.6, col); p.set(fx, fy, 'y0' if col != 'y0' else 'p0')
    p.set(12, 7, 'l2'); p.set(13, 7, 'l1'); p.set(19, 7, 'l2'); p.set(20, 7, 'l1'); p.set(16, 6, 'l1'); p.set(16, 5, 'l2')
    return p.im

PIECES = {
    'tile_floor_01': floor_a, 'tile_floor_02': floor_b, 'wall_plain_01': wall_plain, 'wall_low_01': wall_low, 'wall_side_01': wall_side,
    'wdeco_door_01': door, 'wdeco_door_open_01': door_open, 'wdeco_window_01': window, 'rest_table_small_01': table, 'rest_stove_01': stove,
    'rest_vase_small_01': vase_small, 'rest_vase_large_01': vase_large,
}

def contact(pieces, k=4):
    """A 4x preview of every piece on a light board."""
    order = list(pieces)
    W = 1100; pad = 16
    board = Image.new('RGBA', (W, 760), (236, 232, 224, 255))
    x = pad; y = pad; rowh = 0
    for name in order:
        im = pieces[name].resize((pieces[name].width * k, pieces[name].height * k), Image.NEAREST)
        if x + im.width + pad > W: x = pad; y += rowh + pad; rowh = 0
        board.alpha_composite(im, (x, y)); x += im.width + pad; rowh = max(rowh, im.height)
    return board

def room(pieces, cols=9, rows=6, k=3):
    """The pieces in a room the way the game lays them out: 32 px per cell, back wall 3 blocks tall, floor A/B as a checker."""
    C = 32
    W, H = cols * C, 3 * C + rows * C
    im = Image.new('RGBA', (W, H), (120, 170, 210, 255))
    for y in range(rows):
        for x in range(cols): im.alpha_composite(pieces['tile_floor_01' if (x + y) % 2 == 0 else 'tile_floor_02'], (x * C, 3 * C + y * C))
    for x in range(cols): im.alpha_composite(pieces['wall_plain_01'], (x * C, 0))
    im.alpha_composite(pieces['wdeco_door_01'], (1 * C, 3 * C - 64 - 6 + 6 - 0 - 6 + 0 + 0)) if False else None
    base = 3 * C                                                                                # the floor line (bottom of the wall)
    im.alpha_composite(pieces['wdeco_door_01'], (1 * C, base - 70 + 6))
    im.alpha_composite(pieces['wdeco_door_open_01'], (3 * C, base - 70 + 6))
    im.alpha_composite(pieces['wdeco_window_01'], (4 * C, 3 * C - 96 + 4 + (56 - 28) // 2 - 2))        # window base 42 px up the wall
    for r in range(rows): im.alpha_composite(pieces['wall_side_01'], (0, 0)) if False else None
    im.alpha_composite(pieces['rest_stove_01'], (6 * C, base - 8))                                  # 2 x 2 cells, standing on its bottom edge
    tx, ty = 2 * C, base + 2 * C                                                               # table
    im.alpha_composite(pieces['rest_table_small_01'], (tx, ty))
    im.alpha_composite(pieces['rest_vase_large_01'], (tx + 6, ty - 17))
    im.alpha_composite(pieces['rest_vase_small_01'], (tx + 40, ty - 5))
    return im.resize((W * k, H * k), Image.NEAREST)

def sheet2(pieces, layout_path='assets/td/art_workshop/set_template_layout.json'):
    """The pilot pieces placed on the pixel sheet 2 (480 px wide) exactly where the template has their frames, so the sheet can be opened
    in a drawing app on top of the template guide and edited."""
    import json
    lay = json.load(open(layout_path)); K = lay['k']
    sh = [x for x in lay['sheets'] if x['id'] == 'now_shop'][0]
    im = Image.new('RGBA', (sh['pxW'], sh['pxH']), (0, 0, 0, 0))
    for it in lay['items']:
        if it['sheet'] == sh['id'] and it['file'] in pieces:
            im.alpha_composite(pieces[it['file']], (it['x'] // K, it['y'] // K))
    return im

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'pilot_out'
    os.makedirs(out, exist_ok=True)
    pieces = {n: f() for n, f in PIECES.items()}
    for n, im in pieces.items(): im.save(f'{out}/{n}.png')
    contact(pieces).convert('RGB').save(f'{out}/_contact.png')
    room(pieces).convert('RGB').save(f'{out}/_room.png')
    if os.path.exists('assets/td/art_workshop/set_template_layout.json'): sheet2(pieces).save(f'{out}/pilot_sheet2_px.png')
    print('written', len(pieces), 'pieces to', out)
