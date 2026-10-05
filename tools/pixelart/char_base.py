#!/usr/bin/env python3
"""Layered character base (our own design): 32 x 64 frame, about 58 px tall, a three-head chibi (head about a third of the height, legs a third), soft pastel fashion colours.
Layers (drawn in this order): hair_back, body (skin + face), shoes, bottom, top, apron, hair_front. Each layer is its own PNG per view and frame, so a
character is chosen by picking a hair style, an outfit and colours. Views: down (front), left (side), up (back); right is left mirrored.
Walk: 4 frames per view (stand, step A, stand, step B).
python3 tools/pixelart/char_base.py [OUTDIR]   writes layers/, a walk sheet and a wardrobe preview."""
import sys, os, random
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from shop_pilot import Pix, PIECES

def hx(s): return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5)) + (255,)
def mix(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)
def ramp(c):
    c = hx(c) if isinstance(c, str) else c
    return {'l': mix(c, (255, 255, 255, 255), 0.28), 'm': c, 'd': mix(c, (70, 40, 90, 255), 0.30), 'o': mix(c, (50, 25, 40, 255), 0.58)}

SKIN = {'light': '#f6d3b8', 'tan': '#e7b48f', 'brown': '#b97d5a', 'deep': '#8a5a40'}
HAIR = {'cocoa': '#7a5240', 'black': '#3a3040', 'rose': '#e58aa5', 'sky': '#6fa8dc', 'honey': '#e8c070', 'mint': '#7fc8a9', 'lilac': '#a98ad8'}
CLOTH = {'cream': '#f6ead8', 'sky': '#7fb8e0', 'rose': '#f09db0', 'mint': '#9ad7bd', 'butter': '#f5d77a', 'lilac': '#b9a1e0', 'navy': '#4d6aa6', 'coral': '#f0907a'}
EYE = (58, 42, 58, 255); BLUSH = (240, 150, 160, 255)

# ---- poses: one per frame -------------------------------------------------------------------------------------------------
def pose(view, f):
    """bob (whole body up), lift (the foot that is up, 0/1/2 = left/right in the picture), swing of the arms."""
    step = f in (1, 3)
    P = {'bob': -1 if step else 0, 'll': 0, 'lr': 0, 'al': 0, 'ar': 0, 'dx': 0}
    if view in ('down', 'up'):
        if f == 1: P['ll'] = -2; P['ar'] = -1; P['al'] = 1
        if f == 3: P['lr'] = -2; P['al'] = -1; P['ar'] = 1
    else:                                             # side: the near leg goes forward / back (dx), the arm swings the other way
        if f == 1: P['dx'] = -4
        if f == 3: P['dx'] = 4
    return P

def head_shape(p, x0, x1, y0, y1, col):
    """A rounded head: the corners are cut in steps of 2 and 1 pixel."""
    cut = {(0, 0), (1, 0), (0, 1)}
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dx = min(x - x0, x1 - x); dy = min(y - y0, y1 - y)
            if (dx, dy) in cut or (dy, dx) in cut: continue
            p.set(x, y, col)

def shade_rect(p, x0, y0, x1, y1, r, light_left=True):
    p.rect(x0, y0, x1, y1, r['m'])
    p.vline(x0 if light_left else x1, y0, y1, r['l']); p.vline(x1 if light_left else x0, y0, y1, r['d'])

# ---- layers (3-head proportions: head rows 3..21, torso 23..38, legs 39..57) ---------------------------------------------------
HT, HB = 3, 21          # head top / bottom
TT, TB = 23, 38         # torso top / bottom
FOOT = 57               # last row of the shoes

def body(view, f, skin):
    p = Pix(32, 64); P = pose(view, f); r = ramp(skin); b = P['bob']
    if view in ('down', 'up'):
        for lx, lift in ((11, P['ll']), (17, P['lr'])):
            shade_rect(p, lx, TB + 1 + b, lx + 3, FOOT - 2 + lift, r)
        shade_rect(p, 10, TT + b, 21, TB + b, r); p.rect(14, HB + b, 17, TT + b, r['d'])
        for ax, a in ((7, P['al']), (22, P['ar'])):
            shade_rect(p, ax, TT + 1 + b + a, ax + 2, TB - 3 + b + a, r); p.rect(ax, TB - 2 + b + a, ax + 2, TB + b + a, r['m']); p.hline(ax, ax + 2, TB + b + a, r['d'])
        head_shape(p, 7, 24, HT + b, HB + b, r['m']); p.hline(9, 22, HB - 1 + b, r['d'])
        if view == 'down':
            for ex in (11, 19): p.rect(ex, 12 + b, ex + 1, 15 + b, EYE); p.set(ex, 12 + b, (255, 255, 255, 255))
            p.rect(8, 16 + b, 10, 17 + b, BLUSH); p.rect(21, 16 + b, 23, 17 + b, BLUSH)
            p.hline(15, 16, 18 + b, mix(r['m'], (200, 90, 100, 255), 0.6))
    else:                                              # side, facing left
        dx = P['dx']
        for d in (-dx, dx):
            near = d == dx
            shade_rect(p, 13 + d, TB + 1 + b, 16 + d, FOOT - 2 + (-1 if abs(dx) == 4 and not near else 0), r)
        shade_rect(p, 11, TT + b, 20, TB + b, r); p.rect(13, HB + b, 17, TT + b, r['d'])
        shade_rect(p, 14 - dx // 2, TT + 1 + b, 16 - dx // 2, TB - 3 + b, r); p.rect(14 - dx // 2, TB - 2 + b, 16 - dx // 2, TB + b, r['m'])
        head_shape(p, 8, 24, HT + b, HB + b, r['m']); p.hline(10, 22, HB - 1 + b, r['d'])
        p.rect(11, 12 + b, 12, 15 + b, EYE); p.set(11, 12 + b, (255, 255, 255, 255)); p.rect(9, 16 + b, 11, 17 + b, BLUSH)
        p.set(8, 16 + b, r['d'])
    return p

def shoes(view, f, col):
    p = Pix(32, 64); P = pose(view, f); r = ramp(col)
    if view in ('down', 'up'):
        for lx, lift in ((11, P['ll']), (17, P['lr'])):
            p.rect(lx - 1, FOOT - 2 + lift, lx + 4, FOOT + lift, r['m']); p.hline(lx - 1, lx + 4, FOOT - 2 + lift, r['l']); p.hline(lx - 1, lx + 4, FOOT + lift, r['d'])
    else:
        dx = P['dx']
        for d in (-dx, dx):
            near = d == dx
            y = FOOT - 2 + (-1 if abs(dx) == 4 and not near else 0)
            p.rect(11 + d, y, 18 + d, y + 2, r['m']); p.hline(11 + d, 18 + d, y, r['l']); p.hline(11 + d, 18 + d, y + 2, r['d'])
    return p

def bottom(kind, view, f, col):
    p = Pix(32, 64); P = pose(view, f); r = ramp(col); b = P['bob']
    w0 = 5 if view in ('down', 'up') else 4
    if kind == 'skirt':
        for i, y in enumerate(range(TB - 2, TB + 9)):
            w = w0 + i // 2; p.rect(16 - w, y + b, 15 + w, y + b, r['m']); p.set(16 - w, y + b, r['l']); p.set(15 + w, y + b, r['d'])
        p.hline(16 - w0 - 5, 15 + w0 + 5, TB + 8 + b, r['d'])
    else:                                              # shorts
        x0, x1 = (10, 21) if view in ('down', 'up') else (11, 20)
        shade_rect(p, x0, TB - 2 + b, x1, TB + 5 + b, r)
        if view in ('down', 'up'): p.vline(15, TB + 2 + b, TB + 5 + b, r['d']); p.vline(16, TB + 2 + b, TB + 5 + b, r['d'])
    return p

def top(kind, view, f, col):
    p = Pix(32, 64); P = pose(view, f); r = ramp(col); b = P['bob']
    if view in ('down', 'up'):
        shade_rect(p, 9, TT + b, 22, TB - 1 + b, r)
        for ax, a in ((6, P['al']), (22, P['ar'])): shade_rect(p, ax, TT + 1 + b + a, ax + 3, TT + 7 + b + a, r)
        if kind == 'sailor' and view == 'down':
            p.rect(11, TT + b, 20, TT + 2 + b, (250, 250, 250, 255)); p.vline(15, TT + 3 + b, TT + 6 + b, (240, 120, 140, 255)); p.vline(16, TT + 3 + b, TT + 6 + b, (240, 120, 140, 255))
        p.hline(9, 22, TB - 1 + b, r['d'])
        if view == 'down': p.hline(13, 18, TT + b, r['d'])
    else:
        shade_rect(p, 10, TT + b, 21, TB - 1 + b, r)
        shade_rect(p, 13 - P['dx'] // 2, TT + 1 + b, 17 - P['dx'] // 2, TT + 8 + b, r)
        p.hline(10, 21, TB - 1 + b, r['d'])
    return p

def apron(view, f, col):
    p = Pix(32, 64); P = pose(view, f); r = ramp(col); b = P['bob']
    if view == 'down':
        p.rect(11, TT + 6 + b, 20, TB + 9 + b, r['m']); p.vline(11, TT + 6 + b, TB + 9 + b, r['l']); p.vline(20, TT + 6 + b, TB + 9 + b, r['d']); p.hline(11, 20, TB + 9 + b, r['d'])
        p.vline(12, TT + b, TT + 6 + b, r['m']); p.vline(19, TT + b, TT + 6 + b, r['m']); p.rect(14, TT + 11 + b, 17, TT + 14 + b, r['d'])
    elif view == 'up':
        p.vline(12, TT + b, TT + 6 + b, r['m']); p.vline(19, TT + b, TT + 6 + b, r['m']); p.rect(13, TT + 11 + b, 18, TT + 13 + b, r['m']); p.hline(13, 18, TT + 13 + b, r['d'])
    else:
        p.rect(9, TT + 6 + b, 11, TB + 7 + b, r['m']); p.vline(9, TT + 6 + b, TB + 7 + b, r['l']); p.hline(9, 11, TB + 7 + b, r['d'])
    return p

def hair_back(style, view, f, col):
    p = Pix(32, 64); P = pose(view, f); r = ramp(col); b = P['bob']
    if view == 'down':
        if style in ('bob', 'short'): head_shape(p, 5, 26, HT + 2 + b, HB + 3 + b, r['d'])
        elif style == 'long': head_shape(p, 5, 26, HT + 2 + b, HB + 3 + b, r['d']); p.rect(6, HB + b, 9, TB + 3 + b, r['d']); p.rect(22, HB + b, 25, TB + 3 + b, r['d'])
        elif style == 'twin':
            for tx in (3, 25): shade_rect(p, tx, 12 + b, tx + 4, 31 + b, r)
    elif view == 'left':
        head_shape(p, 14, 28, HT + 2 + b, HB + 3 + b, r['d'])
        if style == 'long': p.rect(18, HB + b, 27, TB + 3 + b, r['d'])
        if style == 'twin': shade_rect(p, 19, 12 + b, 24, 31 + b, r)
    return p

def hair_front(style, view, f, col):
    p = Pix(32, 64); P = pose(view, f); r = ramp(col); b = P['bob']
    if view == 'down':
        head_shape(p, 6, 25, HT - 2 + b, HT + 6 + b, r['m']); p.hline(9, 22, HT - 1 + b, r['l']); p.hline(10, 18, HT + b, r['l'])
        for x in range(7, 25, 3): p.rect(x, HT + 6 + b, x + 1, HT + 8 + b, r['m'])           # fringe points
        p.rect(6, HT + 6 + b, 7, 15 + b, r['m']); p.rect(24, HT + 6 + b, 25, 15 + b, r['d'])
        if style == 'bob': p.rect(5, HT + 7 + b, 7, HB + 1 + b, r['m']); p.rect(24, HT + 7 + b, 26, HB + 1 + b, r['d'])
        if style == 'twin': p.rect(3, 6 + b, 7, 9 + b, (240, 150, 170, 255)); p.rect(24, 6 + b, 28, 9 + b, (240, 150, 170, 255))
        if style == 'long': p.rect(5, HT + 7 + b, 7, TB - 2 + b, r['m']); p.rect(24, HT + 7 + b, 26, TB - 2 + b, r['d'])
    elif view == 'up':
        head_shape(p, 6, 25, HT - 2 + b, HB + 2 + b, r['m']); p.hline(9, 22, HT - 1 + b, r['l'])
        for x in range(9, 25, 4): p.vline(x, 8 + b, HB + b, r['d'])
        if style == 'long': p.rect(5, 9 + b, 26, TB + 2 + b, r['m']); p.vline(11, HB + b, TB + 2 + b, r['d']); p.vline(20, HB + b, TB + 2 + b, r['d'])
        if style == 'bob': p.rect(5, 9 + b, 26, HB + 2 + b, r['m'])
        if style == 'twin':
            for tx in (3, 25): shade_rect(p, tx, 12 + b, tx + 4, 31 + b, r)
    else:                                              # side
        head_shape(p, 7, 25, HT - 2 + b, HT + 6 + b, r['m']); p.hline(9, 22, HT - 1 + b, r['l'])
        p.rect(8, HT + 5 + b, 12, HT + 8 + b, r['m'])
        p.rect(15, HT + 5 + b, 25, HB + b, r['m']); p.vline(25, HT + 5 + b, HB + b, r['d'])
        if style == 'bob': p.rect(15, HT + 5 + b, 26, HB + 2 + b, r['m'])
        if style == 'long': p.rect(15, HT + 5 + b, 26, TB + 2 + b, r['m']); p.vline(26, HT + 5 + b, TB + 2 + b, r['d'])
        if style == 'twin': shade_rect(p, 19, 12 + b, 24, 31 + b, r)
    return p

# ---- composition -------------------------------------------------------------------------------------------------------------
def selout(im):
    """Outline every layer with a dark version of the colour it touches (no black)."""
    out = im.copy(); w, h = im.size
    for y in range(h):
        for x in range(w):
            if im.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and im.getpixel((nx, ny))[3] > 0:
                        c = im.getpixel((nx, ny)); out.putpixel((x, y), mix(c, (50, 25, 40, 255), 0.6)); break
    return out

def layers_for(look, view, f):
    """Ordered list of (name, 32x64 image) for one view and frame. look: skin, hair, hair_color, bottom, bottom_color, top, top_color, shoes, apron."""
    v = 'left' if view == 'right' else view
    L = []
    if look.get('hair'): L.append(('hair_back', hair_back(look['hair'], v, f, HAIR[look['hair_color']])))
    L.append(('body', body(v, f, SKIN[look['skin']])))
    L.append(('shoes', shoes(v, f, look.get('shoes', '#a86a4a'))))
    if look.get('bottom'): L.append(('bottom', bottom(look['bottom'], v, f, CLOTH[look['bottom_color']])))
    if look.get('top'): L.append(('top', top(look['top'], v, f, CLOTH[look['top_color']])))
    if look.get('apron'): L.append(('apron', apron(v, f, CLOTH[look['apron']])))
    if look.get('hair'): L.append(('hair_front', hair_front(look['hair'], v, f, HAIR[look['hair_color']])))
    out = []
    for n, p in L:
        im = selout(p.im if hasattr(p, 'im') else p)
        if view == 'right': im = im.transpose(Image.FLIP_LEFT_RIGHT)
        out.append((n, im))
    return out

def render(look, view, f):
    im = Image.new('RGBA', (32, 64), (0, 0, 0, 0))
    for n, l in layers_for(look, view, f): im.alpha_composite(l)
    return im

LOOKS = {
    'waitress': dict(skin='light', hair='bob', hair_color='cocoa', bottom='skirt', bottom_color='navy', top='plain', top_color='cream', apron='sky', shoes='#a86a4a'),
    'cafe_boy': dict(skin='tan', hair='short', hair_color='black', bottom='shorts', bottom_color='navy', top='plain', top_color='mint', apron='cream', shoes='#7a5240'),
    'rose_girl': dict(skin='light', hair='twin', hair_color='rose', bottom='skirt', bottom_color='lilac', top='sailor', top_color='cream', shoes='#f0c0c8'),
    'sky_long': dict(skin='brown', hair='long', hair_color='sky', bottom='shorts', bottom_color='coral', top='plain', top_color='butter', shoes='#4d6aa6'),
    'mint_chef': dict(skin='deep', hair='bob', hair_color='mint', bottom='shorts', bottom_color='cream', top='plain', top_color='rose', apron='cream', shoes='#7a5240'),
    'honey_long': dict(skin='tan', hair='long', hair_color='honey', bottom='skirt', bottom_color='mint', top='plain', top_color='lilac', shoes='#a86a4a'),
}

def walk_sheet(look, k=4):
    """4 views (down, left, right, up) x 4 frames."""
    views = ['down', 'left', 'right', 'up']
    im = Image.new('RGBA', (4 * 36 + 4, 4 * 68 + 4), (236, 232, 224, 255))
    for r, v in enumerate(views):
        for f in range(4): im.alpha_composite(render(look, v, f), (4 + f * 36, 4 + r * 68))
    return im.resize((im.width * k, im.height * k), Image.NEAREST)

def wardrobe(k=4):
    im = Image.new('RGBA', (len(LOOKS) * 36 + 4, 3 * 68 + 4), (236, 232, 224, 255))
    for i, look in enumerate(LOOKS.values()):
        for r, v in enumerate(('down', 'left', 'up')): im.alpha_composite(render(look, v, 0), (4 + i * 36, 4 + r * 68))
    return im.resize((im.width * k, im.height * k), Image.NEAREST)

def scale_check(k=5):
    P = {n: f() for n, f in PIECES.items()}
    im = Image.new('RGBA', (220, 80), (236, 232, 224, 255))
    im.alpha_composite(render(LOOKS['waitress'], 'down', 0), (6, 8)); im.alpha_composite(render(LOOKS['cafe_boy'], 'left', 0), (40, 8))
    im.alpha_composite(P['wdeco_door_01'], (80, 4)); im.alpha_composite(P['rest_table_small_01'], (124, 16)); im.alpha_composite(render(LOOKS['rose_girl'], 'down', 0), (180, 8))
    return im.resize((im.width * k, im.height * k), Image.NEAREST)

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'char_base_out'
    os.makedirs(out + '/layers', exist_ok=True)
    walk_sheet(LOOKS['waitress']).convert('RGB').save(out + '/walk_sheet_waitress.png')
    wardrobe().convert('RGB').save(out + '/wardrobe.png'); scale_check().convert('RGB').save(out + '/scale_check.png')
    for v in ('down', 'left', 'up'):
        for f in range(4):
            for n, l in layers_for(LOOKS['waitress'], v, f): l.save(f'{out}/layers/{n}_{v}_{f}.png')
    print('written to', out)
