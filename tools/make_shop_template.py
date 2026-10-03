#!/usr/bin/env python3
"""Block template of the shop for the owner to draw over (docs/templates/tpl_shop_blocks.png): floor grid,
two back walls with the places for window / lamp / painting, a counter run of 1x1 modules, a 2x2 table block."""
from PIL import Image, ImageDraw, ImageFont
OUT = 'docs/templates/tpl_shop_blocks.png'
F = 'assets/fonts/NotoSansThai_400Regular.ttf'
CW, CH = 128, 64
W, H = 8, 6
IMG_W, IMG_H = 1500, 1000
OX, OY = 760, 330
CY = (0, 150, 190, 255); MG = (230, 40, 130, 255); GR = (140, 140, 140, 255); K = (50, 50, 50, 255)
def scr(x, y): return (OX + (x - y) * CW / 2, OY + (x + y) * CH / 2)
def diamond(x, y, w=1, h=1): return [scr(x, y), scr(x + w, y), scr(x + w, y + h), scr(x, y + h)]
f = ImageFont.truetype(F, 24); fs = ImageFont.truetype(F, 20); fb = ImageFont.truetype(F, 30)
im = Image.new('RGBA', (IMG_W, IMG_H), (250, 248, 242, 255)); d = ImageDraw.Draw(im)
for y in range(H):
    for x in range(W):
        d.polygon(diamond(x, y), fill=(255, 255, 255, 255) if (x + y) % 2 else (240, 238, 232, 255), outline=GR)
def label(xy, text, font=fs, col=K):
    w = d.textlength(text, font=font)
    d.rectangle([xy[0] - 4, xy[1] - 2, xy[0] + w + 4, xy[1] + font.size + 4], fill=(255, 255, 255, 230))
    d.text(xy, text, font=font, fill=col)
HGT = 210
# back walls as flat blocks: north wall along x at y=0, west wall along y at x=0
def wall_quad(x0, y0, x1, y1, fill):
    a = scr(x0, y0); b = scr(x1, y1)
    d.polygon([a, b, (b[0], b[1] - HGT), (a[0], a[1] - HGT)], fill=fill, outline=K)
wall_quad(0, 0, W, 0, (236, 230, 214, 255))
wall_quad(0, 0, 0, H, (214, 208, 194, 255))
# one-cell overlay slots on the north wall: window, window, lamp, painting, window
def slot(wx, cell, kind, col):
    # cell index along the north wall; overlay occupies one cell, between 24% and 67% of the height
    a = scr(cell, 0); b = scr(cell + 1, 0)
    def pt(u, v): return (a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u - HGT * v)
    if kind == 'lamp': q = [pt(.35, .72), pt(.65, .72), pt(.65, .5), pt(.35, .5)]
    else: q = [pt(.15, .67), pt(.85, .67), pt(.85, .29), pt(.15, .29)]
    d.line(q + [q[0]], fill=col, width=3)
    c = pt(.5, .45 if kind != 'lamp' else .6)
    d.text((c[0] - 24, c[1] - 14), {'window': 'หน้าต่าง', 'lamp': 'โคมไฟ', 'painting': 'ภาพวาด'}[kind], font=fs, fill=col)
for cell, kind, col in [(1, 'window', CY), (2, 'window', CY), (4, 'lamp', MG), (5, 'painting', MG), (6, 'window', CY)]:
    slot(0, cell, kind, col)
# counter run of 1x1 module blocks along the north wall
MH = 75   # module height 300 px at 1/4 scale... shown at 2x scale = 75 px per cell edge unit
def block(x, y, w, h, hgt, top, left, right, name):
    p = diamond(x, y, w, h)
    up = lambda q: (q[0], q[1] - hgt)
    d.polygon([p[3], p[2], up(p[2]), up(p[3])], fill=left, outline=K)
    d.polygon([p[2], p[1], up(p[1]), up(p[2])], fill=right, outline=K)
    d.polygon([up(q) for q in p], fill=top, outline=K)
    c = up(((p[0][0] + p[2][0]) / 2, (p[0][1] + p[2][1]) / 2))
    d.text((c[0] - 24, c[1] - 12), name, font=fs, fill=K)
for i, n in enumerate(['เคาน์เตอร์', 'อ่างล้าง', 'เคาน์เตอร์', 'เตา', 'เคาน์เตอร์', 'เคาน์เตอร์']):
    block(i + 1, 0.05, 1, 0.9, 75, (200, 205, 215, 255), (228, 224, 214, 255), (204, 200, 190, 255), '')
    c = scr(i + 1.5, 0.5); d.text((c[0] - 30, c[1] - 75 - 12), n, font=fs, fill=K)
# a 2x2 table block with chairs
block(2.5, 3.5, 2, 2, 38, (216, 190, 150, 255), (190, 160, 120, 255), (170, 142, 106, 255), '')
c = scr(3.5, 4.5); d.text((c[0] - 22, c[1] - 50), 'โต๊ะ 2x2', font=fs, fill=K)
# front is open: label
label((scr(W, H)[0] - 190, scr(W, H)[1] + 10), 'ด้านหน้าเปิดโล่ง (ลานหน้าร้าน)')
label((scr(0, 0)[0] - 330, scr(0, 0)[1] - 140), 'ผนังเรียบ: ไม่มีของติดผนัง', fs)
d.rectangle([20, 18, 1480, 160], fill=(0, 0, 0, 175))
d.text((30, 22), 'แม่แบบร้านแบบบล็อก: ใช้ดูว่าแต่ละชิ้นอยู่ตรงไหน', font=fb, fill=(255, 255, 255, 255))
for i, t in enumerate(['เส้นฟ้า = ที่วางหน้าต่าง (256x840)   เส้นชมพู = ที่วางโคมไฟ/ภาพวาด (256x840)',
                       'พื้น 8x6 ช่อง ผนังด้านหลัง 2 ด้าน ด้านหน้าเปิด เคาน์เตอร์เรียง 1 ช่องต่อชิ้นชิดผนัง',
                       'วาดทีละชิ้นตามแม่แบบของแต่ละชนิด แล้วเกมจะเอามาประกอบให้ (ภาพนี้ไว้ดูภาพรวมเท่านั้น)']):
    d.text((30, 70 + i * 28), t, font=fs, fill=(255, 235, 150, 255))
im.convert('RGB').save(OUT)
print('ok')
