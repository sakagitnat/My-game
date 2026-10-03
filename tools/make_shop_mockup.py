#!/usr/bin/env python3
"""Mock-up of the shop assembled from separate pieces: floor, plain walls, wall overlays, furniture modules.
Reference only (docs/templates/examples/shop_mockup.png); not the in-game render."""
from PIL import Image, ImageDraw, ImageFont
import random, os
random.seed(7)
OUT = 'docs/templates/examples/shop_mockup.png'
F = 'assets/fonts/NotoSansThai_400Regular.ttf'
OL = (62, 42, 30, 255)
CW, CH = 128, 64            # cell on screen (2x the game)
W, H = 8, 6                  # shop cells (x to the right-down, y to the left-down)
IMG_W, IMG_H = 1500, 1000
OX, OY = 760, 330            # screen position of the shop's north corner (cell 0,0)

def scr(x, y): return (OX + (x - y) * CW / 2, OY + (x + y) * CH / 2)
def diamond(x, y, w=1, h=1):
    return [scr(x, y), scr(x + w, y), scr(x + w, y + h), scr(x, y + h)]

im = Image.new('RGBA', (IMG_W, IMG_H), (96, 150, 70, 255))
d = ImageDraw.Draw(im)
# ground: grass with dirt patches, road along the top, sea at the bottom left
for y in range(-9, 22):
    for x in range(-9, 22):
        p = diamond(x, y)
        cx = sum(a for a, b in p) / 4; cy = sum(b for a, b in p) / 4
        if cx < -80 or cx > IMG_W + 80 or cy < -40 or cy > IMG_H + 40: continue
        g = random.randint(-8, 8)
        col = (96 + g, 150 + g, 70 + g, 255)
        if random.random() < 0.18: col = (176 + g, 138 + g, 96 + g, 255)
        if y < -3: col = (110, 110, 118, 255) if y > -7 else (96 + g, 150 + g, 70 + g, 255)
        if x - y < -8 or (y > 8 and x < 3): col = (62 + g, 150 + g, 200 + g, 255)
        d.polygon(p, fill=col)
# floor: wooden planks in two tones
for y in range(H):
    for x in range(W):
        t = 0 if (x + y) % 2 else 1
        d.polygon(diamond(x, y), fill=[(214, 170, 120, 255), (200, 154, 106, 255)][t])
        d.line(diamond(x, y) + [scr(x, y)], fill=(180, 138, 96, 255), width=1)
# a rug
d.polygon([scr(3.1, 2.6), scr(5.1, 2.6), scr(5.1, 3.9), scr(3.1, 3.9)], fill=(70, 120, 190, 255), outline=(240, 240, 250, 255))

def wall_texture(n, overlays):
    """n cells wide, 256 px per cell, 840 tall: plain wall + overlays {cell: kind}."""
    t = Image.new('RGBA', (256 * n, 840), (240, 228, 200, 255)); td = ImageDraw.Draw(t)
    for x in range(0, 256 * n, 64): td.line([(x, 40), (x, 750)], fill=(232, 219, 188, 255), width=2)
    td.rectangle([0, 0, 256 * n, 40], fill=(150, 100, 70, 255)); td.rectangle([0, 750, 256 * n, 840], fill=(150, 100, 70, 255))
    td.line([(0, 40), (256 * n, 40)], fill=OL, width=5); td.line([(0, 750), (256 * n, 750)], fill=OL, width=5)
    for c, kind in overlays.items():
        o = Image.new('RGBA', (256, 840), (0, 0, 0, 0)); od = ImageDraw.Draw(o)
        if kind == 'window':
            od.rectangle([40, 240, 216, 560], fill=(150, 210, 235, 255), outline=OL, width=8)
            od.line([(128, 240), (128, 560)], fill=OL, width=6); od.line([(40, 400), (216, 400)], fill=OL, width=6)
            od.rectangle([24, 560, 232, 590], fill=(150, 100, 70, 255), outline=OL, width=6)
        elif kind == 'painting':
            od.rectangle([50, 250, 206, 430], fill=(120, 80, 50, 255), outline=OL, width=6)
            od.rectangle([66, 266, 190, 414], fill=(120, 190, 230, 255))
            od.polygon([(66, 414), (110, 330), (150, 390), (170, 350), (190, 414)], fill=(80, 150, 90, 255))
        elif kind == 'lamp':
            od.line([(128, 250), (128, 300)], fill=OL, width=8)
            od.ellipse([98, 290, 158, 360], fill=(255, 222, 130, 255), outline=OL, width=6)
        t.alpha_composite(o, (256 * c, 0))
    return t

# affine for the shear: input = (4X, 840 - 2X + 4(Y - 210))  at 2x scale
def shear(tex, n):
    outw, outh = 64 * n, 210 + 32 * n
    return tex.transform((outw, outh), Image.AFFINE, (4, 0, 0, -2, 4, 840 - 4 * 210), resample=Image.BILINEAR)

def shade(img, f):
    r, g, b, a = img.split()
    from PIL import ImageEnhance
    return Image.merge('RGBA', (*[c.point(lambda v: int(v * f)) for c in (r, g, b)], a))

# back walls: north (along x, y=0) and west (along y, x=0)
nw = shear(wall_texture(W, {1: 'window', 2: 'window', 4: 'lamp', 5: 'painting', 6: 'window'}), W)
sx, sy = scr(0, 0)
im.alpha_composite(nw, (int(sx), int(sy - 210)))
ww = shade(shear(wall_texture(H, {1: 'window', 2: 'painting', 4: 'window'}), H).transpose(Image.FLIP_LEFT_RIGHT), 0.82)
wx, wy = scr(0, 0)
im.alpha_composite(ww, (int(wx - 64 * H), int(wy - 210)))

# furniture modules along the north wall (run NW -> SE), drawn at 1/8 of the 1024 canvas
HT = 300
def poly(dd, pts, fill, line=None, w=6):
    dd.polygon(pts, fill=fill)
def module(kind):
    m = Image.new('RGBA', (1024 * 2, 1024 * 2), (0, 0, 0, 0)); md = ImageDraw.Draw(m)
    S = 2
    def P(pts): return [(x * S, y * S) for x, y in pts]
    L, B, R, T = (0, 768), (512, 1024), (1024, 768), (512, 512)
    Lt, Bt, Rt, Tt = (0, 768 - HT), (512, 1024 - HT), (1024, 768 - HT), (512, 512 - HT)
    body = (232, 226, 214, 255)
    md.polygon(P([Bt, Rt, R, B]), fill=(196, 190, 180, 255))
    md.polygon(P([Lt, Bt, B, L]), fill=body)
    md.polygon(P([Lt, Tt, Rt, Bt]), fill=(70, 74, 80, 255) if kind == 'stove' else (118, 126, 134, 255))
    md.line(P([L, B]), fill=OL, width=12); md.line(P([Lt, Bt]), fill=OL, width=12); md.line(P([Tt, Rt]), fill=OL, width=12)
    def fp(u, v): return (L[0] + (B[0] - L[0]) * u, L[1] + (B[1] - L[1]) * u - HT * v)
    if kind in ('counter', 'sink'):
        md.polygon(P([fp(.12, .12), fp(.88, .12), fp(.88, .86), fp(.12, .86)]), fill=(214, 206, 192, 255), outline=(150, 140, 128, 255))
    if kind == 'sink':
        md.polygon(P([(300, 468), (512, 468 - 105), (724, 468), (512, 468 + 105)]), fill=(150, 170, 190, 255), outline=OL)
    if kind == 'stove':
        md.polygon(P([fp(.12, .12), fp(.88, .12), fp(.88, .62), fp(.12, .62)]), fill=(60, 62, 68, 255), outline=(150, 140, 128, 255))
        for cx in (400, 624): md.ellipse([(cx - 70) * S, (468 - 34) * S, (cx + 70) * S, (468 + 34) * S], fill=(30, 30, 34, 255), outline=(200, 200, 205, 255), width=6)
    return m.resize((128, 128), Image.LANCZOS)

def put(img, x, y, kind):
    cx, cy = scr(x + .5, y + .5)
    # module canvas: base diamond centre at (64, 96)
    im.alpha_composite(img, (int(cx - 64), int(cy - 96)))
run = ['counter', 'sink', 'counter', 'stove', 'counter', 'counter']
for i, k in enumerate(run):
    put(module(k), i + 1, 0, k)

# tables with chairs (simple boxes) and plants
def box(x, y, w, h, hgt, top, side_l, side_r):
    p = diamond(x, y, w, h)
    up = lambda q: (q[0], q[1] - hgt)
    d.polygon([p[3], p[2], up(p[2]), up(p[3])], fill=side_l)
    d.polygon([p[2], p[1], up(p[1]), up(p[2])], fill=side_r)
    d.polygon([up(q) for q in p], fill=top, outline=OL)
for (tx, ty) in [(1.6, 2.2), (5.6, 1.9), (2.0, 4.4)]:
    for (cx, cy) in [(tx - .45, ty + .5), (tx + 1.65, ty + .5), (tx + .5, ty - .45), (tx + .5, ty + 1.6)]:
        box(cx - .15, cy - .15, .3, .3, 22, (90, 130, 190, 255), (70, 105, 160, 255), (60, 95, 150, 255))
    box(tx, ty, 1.0, 1.0, 38, (178, 128, 84, 255), (150, 104, 66, 255), (130, 90, 56, 255))
def plant(x, y):
    cx, cy = scr(x, y)
    d.polygon([(cx - 14, cy), (cx + 14, cy), (cx + 10, cy + 20), (cx - 10, cy + 20)], fill=(196, 110, 70, 255), outline=OL)
    for ang in (-28, -12, 0, 12, 28):
        d.line([(cx, cy), (cx + ang, cy - 40 + abs(ang) * .4)], fill=(60, 140, 70, 255), width=8)
for p in [(7.4, 5.4), (0.7, 5.5), (7.4, 1.0)]: plant(*p)

# door on the open front, awning
fx, fy = scr(W, 3)
# labels
f = ImageFont.truetype(F, 30); f2 = ImageFont.truetype(F, 22)
d.rectangle([20, 18, 1480, 66], fill=(0, 0, 0, 170))
d.text((30, 22), 'ภาพจำลอง: ร้านที่ประกอบจากชิ้นแยก (ผนังเรียบ + หน้าต่าง/โคมไฟ/ภาพวาดซ้อนผนัง + เคาน์เตอร์โมดูลต่อกัน + โต๊ะ)', font=f2, fill=(255, 255, 255, 255))
d.rectangle([20, IMG_H - 52, 1100, IMG_H - 14], fill=(0, 0, 0, 170))
d.text((30, IMG_H - 48), 'ไม่ใช่ภาพจริงในเกม ใช้ดูว่าชิ้นส่วนมาประกอบกันแล้วเป็นอย่างไร', font=f2, fill=(255, 255, 255, 255))
im.convert('RGB').save(OUT)
print('ok')
