#!/usr/bin/env python3
"""Pilot character (the restaurant owner): 32 x 64 frame, about 58 px tall (1.8 blocks), a chibi with a big head, in the seaside palette (blue shirt, cream apron).
Three views: front, side (left; the right is it mirrored) and back. One still pose each, no walking yet.
python3 tools/pixelart/characters.py [OUTDIR]   writes char_front.png, char_side.png, char_back.png (32x64) and char_sheet.png (a scale preview)"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
from shop_pilot import Pix, PIECES, T
from room_mock import outline

def _out(p):
    return outline(p, 'h0')

def front():
    p = Pix(32, 64)
    # legs and shoes (feet on row 58)
    for lx in (11, 17): p.rect(lx, 47, lx + 3, 55, 'b0'); p.vline(lx, 47, 55, 'b1')
    for lx in (10, 17): p.rect(lx, 56, lx + 4, 58, 'w1'); p.hline(lx, lx + 4, 56, 'w3')
    # torso: blue shirt, cream apron
    p.rect(9, 30, 22, 47, 'b2'); p.vline(9, 30, 47, 'b3'); p.vline(22, 30, 47, 'b1')
    p.rect(12, 34, 19, 47, 'c3'); p.hline(12, 19, 34, 'c4'); p.vline(12, 34, 47, 'c4'); p.vline(19, 34, 47, 'n1'); p.hline(12, 19, 47, 'n0')
    p.vline(12, 30, 34, 'c2'); p.vline(19, 30, 34, 'c2')                          # apron straps
    p.rect(14, 38, 17, 41, 'c2'); p.hline(14, 17, 38, 'n1')                      # apron pocket
    p.hline(9, 22, 30, 'b4')
    # arms and hands
    for ax, c in ((6, 'b3'), (23, 'b1')): p.rect(ax, 31, ax + 2, 42, 'b2'); p.vline(ax, 31, 42, c)
    for hx in (6, 23): p.rect(hx, 43, hx + 2, 46, 'k1'); p.hline(hx, hx + 2, 46, 'k0')
    # head
    p.rect(8, 6, 23, 28, 'k1'); p.rect(7, 10, 24, 24, 'k1')
    p.rect(9, 7, 22, 8, 'k2')
    p.vline(23, 10, 26, 'k0'); p.hline(10, 21, 28, 'k0'); p.set(8, 27, 'k0')
    # hair: dark cap with a fringe
    p.rect(7, 4, 24, 12, 'h1'); p.rect(6, 7, 7, 17, 'h1'); p.rect(24, 7, 25, 17, 'h1')
    p.hline(9, 22, 3, 'h1'); p.hline(8, 23, 4, 'h2')
    for x in range(9, 23, 3): p.rect(x, 12, x + 1, 13, 'h1')
    p.hline(10, 20, 6, 'h2')
    # face
    for ex in (11, 19): p.rect(ex, 18, ex + 1, 21, 'e0'); p.set(ex, 18, 'c4')
    p.rect(9, 22, 10, 23, 'p1'); p.rect(21, 22, 22, 23, 'p1')                      # cheeks
    p.hline(14, 17, 24, 'k0'); p.set(15, 25, 'p0'); p.set(16, 25, 'p0')            # mouth
    p.set(15, 21, 'k0')
    return _out(p)

def back():
    p = Pix(32, 64)
    for lx in (11, 17): p.rect(lx, 47, lx + 3, 55, 'b0'); p.vline(lx, 47, 55, 'b1')
    for lx in (10, 17): p.rect(lx, 56, lx + 4, 58, 'w1'); p.hline(lx, lx + 4, 56, 'w3')
    p.rect(9, 30, 22, 47, 'b2'); p.vline(9, 30, 47, 'b3'); p.vline(22, 30, 47, 'b1'); p.hline(9, 22, 30, 'b4')
    p.rect(13, 36, 18, 38, 'c3'); p.hline(13, 18, 36, 'c4')                          # apron bow
    p.vline(12, 30, 36, 'c2'); p.vline(19, 30, 36, 'c2')
    for ax, c in ((6, 'b3'), (23, 'b1')): p.rect(ax, 31, ax + 2, 42, 'b2'); p.vline(ax, 31, 42, c)
    for hx in (6, 23): p.rect(hx, 43, hx + 2, 46, 'k1'); p.hline(hx, hx + 2, 46, 'k0')
    p.rect(8, 6, 23, 28, 'k1'); p.rect(7, 10, 24, 24, 'k1'); p.hline(10, 21, 28, 'k0')
    p.rect(7, 4, 24, 26, 'h1'); p.rect(6, 7, 7, 22, 'h1'); p.rect(24, 7, 25, 22, 'h1')   # all hair seen from behind
    p.hline(9, 22, 3, 'h1'); p.hline(8, 23, 4, 'h2'); p.hline(10, 20, 6, 'h2')
    for x in range(9, 23, 4): p.vline(x, 9, 24, 'h0')
    return _out(p)

def side():
    """Facing left."""
    p = Pix(32, 64)
    p.rect(12, 47, 17, 55, 'b0'); p.vline(12, 47, 55, 'b1')
    p.rect(8, 56, 17, 58, 'w1'); p.hline(8, 17, 56, 'w3')
    p.rect(10, 30, 21, 47, 'b2'); p.vline(10, 30, 47, 'b3'); p.vline(21, 30, 47, 'b1'); p.hline(10, 21, 30, 'b4')
    p.rect(8, 34, 12, 47, 'c3'); p.vline(8, 34, 47, 'c4'); p.hline(8, 12, 47, 'n0')           # apron in front
    p.rect(13, 31, 17, 42, 'b3'); p.vline(13, 31, 42, 'b4'); p.vline(17, 31, 42, 'b1')         # near arm
    p.rect(13, 43, 17, 46, 'k1'); p.hline(13, 17, 46, 'k0')
    p.rect(8, 6, 23, 28, 'k1'); p.rect(7, 10, 23, 24, 'k1'); p.hline(10, 22, 28, 'k0'); p.vline(23, 10, 26, 'k0')
    p.rect(6, 4, 24, 11, 'h1'); p.rect(15, 5, 25, 24, 'h1'); p.rect(21, 9, 25, 26, 'h1')       # hair: fringe, then all the back of the head
    p.hline(8, 22, 3, 'h1'); p.hline(8, 22, 4, 'h2'); p.hline(8, 14, 12, 'h1')
    p.rect(9, 17, 10, 20, 'e0'); p.set(9, 17, 'c4')                                              # eye
    p.rect(8, 22, 9, 23, 'p1'); p.hline(8, 9, 25, 'p0'); p.set(7, 20, 'k0')                      # cheek, mouth, nose
    return _out(p)

VIEWS = {'char_front': front, 'char_side': side, 'char_back': back}

def sheet(views, k=6):
    """The views beside a door (64 px of wall height, a person is about 58 px) and a table, at one scale."""
    P = {n: f() for n, f in PIECES.items()}
    im = Image.new('RGBA', (32 * 3 + 32 + 64 + 48, 72), (236, 232, 224, 255))
    x = 8
    for v in views: im.alpha_composite(v, (x, 4)); x += 36
    x += 4; im.alpha_composite(P['wdeco_door_01'], (x, 2)); x += 40
    im.alpha_composite(P['rest_table_small_01'].crop((0, 0, 64, 64)), (x, 8))
    return im.resize((im.width * k, im.height * k), Image.NEAREST)

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'char_out'
    os.makedirs(out, exist_ok=True)
    made = {n: f() for n, f in VIEWS.items()}
    for n, im in made.items(): im.save(f'{out}/{n}.png')
    sheet([made['char_front'], made['char_side'], made['char_back']]).convert('RGB').save(f'{out}/char_sheet.png')
    print('written', len(made), 'views to', out)
