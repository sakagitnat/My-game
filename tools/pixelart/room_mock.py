#!/usr/bin/env python3
"""A composed restaurant room made of the pilot pieces plus a few more drawn by code (chair, shelf, plant, rug, lamp, painting), laid out the way the
game lays things out: 32 px per cell, back wall 3 blocks, thick side posts overlapping the corners, things standing against the wall overlapping it a little.
python3 tools/pixelart/room_mock.py [OUT.png]   (a preview of a layout; nothing here goes into the game)"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
from shop_pilot import Pix, PIECES, wall_side, T

def chair(front):
    p = Pix(32, 48)
    if front:                                   # we see its front: the back rest behind, seat and legs
        p.rect(7, 6, 24, 22, 'w3'); p.hline(7, 24, 6, 'w5'); p.vline(7, 6, 22, 'w4'); p.vline(24, 6, 22, 'w1')
        for x in (11, 15, 19): p.vline(x, 9, 20, 'w2')
        p.rect(5, 23, 26, 30, 'w5'); p.hline(5, 26, 23, 'w6'); p.hline(5, 26, 30, 'w2')
        for lx in (6, 23): p.rect(lx, 31, lx + 2, 44, 'w2'); p.vline(lx, 31, 44, 'w3')
        p.hline(5, 26, 38, 'w1') if False else None
    else:                                       # we see its back
        p.rect(6, 12, 25, 36, 'w3'); p.hline(6, 25, 12, 'w5'); p.vline(6, 12, 36, 'w4'); p.vline(25, 12, 36, 'w1')
        for x in (10, 14, 18, 22): p.vline(x, 15, 34, 'w2')
        p.rect(5, 37, 26, 40, 'w2'); p.hline(5, 26, 40, 'w1')
        for lx in (6, 23): p.rect(lx, 41, lx + 2, 46, 'w2')
    for lx in (6, 23): p.hline(lx, lx + 2, 45 if front else 47, 'w0')
    return outline(p)

def outline(p, c='w0'):
    mark = []
    for y in range(p.h):
        for x in range(p.w):
            if p.get(x, y)[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < p.w and 0 <= ny < p.h and p.get(nx, ny)[3] > 0: mark.append((x, y)); break
    for x, y in mark: p.set(x, y, c)
    return p.im

def shelf():
    p = Pix(32, 80)
    p.rect(0, 0, 31, 79, 'w2'); p.vline(0, 0, 79, 'w4'); p.vline(1, 0, 79, 'w3'); p.vline(31, 0, 79, 'w1'); p.hline(0, 31, 0, 'w5')
    cols = ['b2', 'p0', 'c3', 'y0', 'l1', 'b1', 'p1', 'c2']
    for i, y0 in enumerate((4, 22, 40, 58)):
        p.rect(3, y0, 28, y0 + 13, 'w0')
        x = 4
        for k in range(8):
            h = 9 + (k * 5 + i * 3) % 4; w = 2 + (k + i) % 2
            if x + w > 28: break
            p.rect(x, y0 + 14 - h, x + w - 1, y0 + 13, cols[(k + i * 2) % len(cols)]); p.vline(x, y0 + 14 - h, y0 + 13, 'c3'); x += w + 1
        p.rect(2, y0 + 14, 29, y0 + 16, 'w4'); p.hline(2, 29, y0 + 14, 'w6'); p.hline(2, 29, y0 + 16, 'w1')
    p.rect(0, 76, 31, 79, 'w1')
    return outline(p)

def plant():
    p = Pix(32, 64)
    for cx, cy, r, c in ((16, 24, 11, 'l1'), (9, 32, 8, 'l0'), (23, 32, 8, 'l0'), (14, 16, 7, 'l2'), (21, 22, 6, 'l2'), (16, 38, 7, 'l1')): p.disc(cx, cy, r, c)
    for x, y in ((10, 22), (18, 14), (22, 26), (14, 30), (8, 34), (24, 34)): p.set(x, y, 'l2'); p.set(x + 1, y + 1, 'l0')
    p.rect(9, 44, 22, 62, 'w4'); p.hline(8, 23, 44, 'w5'); p.hline(8, 23, 46, 'w3'); p.vline(9, 46, 62, 'w5'); p.vline(22, 46, 62, 'w2'); p.hline(9, 22, 62, 'w1')
    p.rect(9, 47, 22, 49, 'w3')
    return outline(p, 'w0')

def rug():
    p = Pix(64, 64)
    p.rect(0, 0, 63, 63, 'b1'); p.rect(3, 3, 60, 60, 'c3'); p.rect(6, 6, 57, 57, 'b2')
    for x in range(8, 56, 4): p.set(x, 8, 'c3'); p.set(x + 1, 55, 'c3')
    for y in range(8, 56, 4): p.set(8, y, 'c3'); p.set(55, y + 1, 'c3')
    p.rect(10, 10, 53, 53, 'c2'); p.disc(32, 32, 14, 'b3'); p.disc(32, 32, 9, 'c3'); p.disc(32, 32, 4, 'b2')
    for sx, sy in ((14, 14), (49, 14), (14, 49), (49, 49)): p.disc(sx, sy, 2, 'b2')
    return p.im

def lamp():
    p = Pix(32, 80)
    p.rect(8, 4, 23, 22, 'c3'); p.hline(8, 23, 4, 'c4'); p.vline(8, 4, 22, 'c4'); p.vline(23, 4, 22, 'c1'); p.hline(8, 23, 22, 'c1'); p.hline(10, 21, 5, 'r2')
    p.rect(15, 23, 16, 70, 's2'); p.vline(15, 23, 70, 's3')
    p.disc(16, 74, 7, 's1'); p.rect(9, 72, 22, 77, 's1'); p.hline(9, 22, 72, 's2')
    return outline(p, 'n0')

def painting():
    p = Pix(32, 32)
    p.rect(2, 4, 29, 27, 'w3'); p.hline(2, 29, 4, 'w5'); p.hline(2, 29, 27, 'w1')
    p.rect(5, 7, 26, 24, 'g1'); p.rect(5, 17, 26, 24, 'b2'); p.hline(5, 26, 17, 'b4')
    p.disc(21, 12, 2.5, 'r2'); p.rect(11, 12, 15, 17, 'c3'); p.vline(13, 8, 17, 'w1')       # sun and a sailboat
    for x in range(6, 26, 3): p.set(x, 20, 'b3')
    return p.im

def build(cols=13, rows=9, k=3):
    P = {n: f() for n, f in PIECES.items()}
    C = 32; PAD = 12
    W = cols * C + PAD * 2; wall = 3 * C
    H = wall + rows * C + 4
    im = Image.new('RGBA', (W, H), (110, 160, 90, 255))
    def at(piece, x, y): im.alpha_composite(piece, (PAD + x, y))
    fl_a, fl_b = P['tile_floor_01'], P['tile_floor_02']
    for y in range(rows):
        for x in range(cols): at(fl_b if (x * 7 + y * 13) % 5 == 0 else fl_a, x * C, wall + y * C)
    for x in range(cols): at(P['wall_plain_01'], x * C, 0)
    # shadow of the back wall on the floor
    sh = Image.new('RGBA', (cols * C, 14), (0, 0, 0, 0))
    for yy in range(14):
        a = int(70 * (1 - yy / 14)); [sh.putpixel((xx, yy), (30, 20, 12, a)) for xx in range(cols * C)]
    at(sh, 0, wall)
    # wall decoration
    at(P['wdeco_door_01'], 5 * C, wall - 70 + 6)
    for wx in (2, 9): at(P['wdeco_window_01'], wx * C, 16)
    at(painting(), 7 * C + 0, 24)
    objs = []                                                       # (foot y, x, y, piece)
    def put(piece, x, foot, dy=0): objs.append((foot, x, foot - piece.height + dy, piece))
    # in a row along the back wall: shelf, stove (overlaps the wall by its top 8 px), plant
    put(shelf(), 0 * C + 16, wall + 1 * C + 8)
    put(P['rest_stove_01'], 10 * C, wall + 1 * C + 0)
    put(plant(), 12 * C - 2, wall + 1 * C)
    put(lamp(), 3 * C + 0, wall + 1 * C + 8)
    # dining: a rug, a table with two chairs on each long side and vases on top
    rx, ry = 3 * C, wall + 3 * C
    at(rug(), rx + 0, ry + 0)
    tx, ty = rx, ry + 8
    ch_up = chair(False); ch_dn = chair(True)
    put(ch_dn, tx + 0, ty + 4 + 8); put(ch_dn, tx + 32, ty + 4 + 8)
    put(P['rest_table_small_01'], tx, ty + 64)
    put(P['rest_vase_large_01'], tx + 8, ty + 28 + 4); put(P['rest_vase_small_01'], tx + 40, ty + 34 + 4)
    put(ch_up, tx + 0, ty + 64 + 20); put(ch_up, tx + 32, ty + 64 + 20)
    # second table on the right with chairs
    t2x, t2y = 8 * C, wall + 4 * C + 8
    put(ch_dn, t2x, t2y + 12); put(ch_dn, t2x + 32, t2y + 12)
    put(P['rest_table_small_01'], t2x, t2y + 64)
    put(ch_up, t2x, t2y + 64 + 20); put(ch_up, t2x + 32, t2y + 64 + 20)
    put(plant(), 16, wall + 8 * C); put(plant(), 12 * C - 12, wall + 8 * C)
    for foot, x, y, piece in sorted(objs, key=lambda o: o[0]):
        sd = Image.new('RGBA', (piece.width, 6), (0, 0, 0, 0))
        for xx in range(2, piece.width - 2):
            for yy in range(6): sd.putpixel((xx, yy), (30, 20, 12, 46))
        at(sd, x, foot - 3)
        at(piece, x, y)
    # side posts (thick), drawn over the ends of the back wall; the cap is plain
    post = wall_side()
    stack = Image.new('RGBA', (12, wall + rows * C + 96), (0, 0, 0, 0))
    for i in range(-1, rows):
        stack.alpha_composite(post, (0, wall + (i + 1) * C - 96))            # one piece more than cells, from a wall height above the first edge
    for px in (PAD - 6, PAD + cols * C - 6):
        im.alpha_composite(stack.crop((0, 0, 12, wall + rows * C)), (px, 0))
    return im.resize((W * k, H * k), Image.NEAREST)

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'room_mock.png'
    build().convert('RGB').save(out); print('written', out)
