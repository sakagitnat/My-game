#!/usr/bin/env python3
"""Rough mock-up of the shop in a Stardew-style top-down (3/4) view: the same pieces on a plain square grid. Reference only."""
from PIL import Image, ImageDraw, ImageFont
OUT = 'docs/templates/examples/shop_topdown_mockup.png'
F = 'assets/fonts/NotoSansThai_400Regular.ttf'
C = 96                      # one cell in pixels
GW, GH = 12, 8              # cells shown
OX, OY = 60, 150
OL = (62, 42, 30, 255)
im = Image.new('RGBA', (GW * C + 120, GH * C + 300), (96, 150, 70, 255)); d = ImageDraw.Draw(im)
fnt = ImageFont.truetype(F, 24); fs = ImageFont.truetype(F, 20)
def R(x, y, w, h, fill, line=OL, lw=3):
    d.rectangle([OX + x * C, OY + y * C, OX + (x + w) * C, OY + (y + h) * C], fill=fill, outline=line, width=lw)
# ground around: dirt and grass, sea on the left
for y in range(-1, GH + 1):
    for x in range(-1, GW + 1):
        if x < 0: col = (70, 150, 200, 255)
        elif (x * 7 + y * 3) % 5 == 0: col = (176, 138, 96, 255)
        else: col = (100 + (x + y) % 2 * 8, 154, 72, 255)
        d.rectangle([OX + x * C, OY + y * C, OX + (x + 1) * C, OY + (y + 1) * C], fill=col)
# shop: interior 8 x 5 cells at (2,2); back wall is 2 cells tall (front face), side walls thin
SX, SY, SW, SH = 2, 2, 8, 5
for y in range(SH):
    for x in range(SW):
        R(SX + x, SY + y, 1, 1, (214, 170, 120, 255) if (x + y) % 2 else (200, 154, 106, 255), line=(180, 138, 96, 255), lw=1)
R(SX + 2.4, SY + 2.6, 2.2, 1.4, (70, 120, 190, 255), line=(240, 240, 250, 255))   # rug
# back wall (front face) 2 cells tall above the floor
R(SX, SY - 2, SW, 2, (240, 228, 200, 255))
R(SX, SY - 2, SW, 0.25, (150, 100, 70, 255))
R(SX, SY - 0.25, SW, 0.25, (150, 100, 70, 255))
for wx in (1, 3, 6):    # windows
    R(SX + wx + 0.15, SY - 1.7, 0.7, 1.0, (150, 210, 235, 255))
R(SX + 4.2, SY - 1.6, 0.6, 0.8, (120, 80, 50, 255)); R(SX + 4.28, SY - 1.52, 0.44, 0.64, (120, 190, 230, 255), line=None)   # painting
d.ellipse([OX + (SX + 5.35) * C, OY + (SY - 1.5) * C, OX + (SX + 5.65) * C, OY + (SY - 1.15) * C], fill=(255, 222, 130, 255), outline=OL, width=3)  # lamp
# side walls: thin
R(SX - 0.25, SY - 2, 0.25, SH + 2, (214, 208, 194, 255))
R(SX + SW, SY - 2, 0.25, SH + 2, (214, 208, 194, 255))
# counter run along the back wall: front view, top strip visible
for i, k in enumerate(['counter', 'sink', 'counter', 'stove', 'counter', 'counter']):
    x = SX + 1 + i
    R(x, SY, 1, 0.35, (118, 126, 134, 255) if k != 'stove' else (70, 74, 80, 255))
    R(x, SY + 0.35, 1, 0.9, (232, 226, 214, 255))
    if k == 'sink': R(x + 0.25, SY + 0.07, 0.5, 0.2, (150, 170, 190, 255), line=OL, lw=2)
    if k == 'stove':
        for bx in (0.3, 0.7): d.ellipse([OX + (x + bx - .1) * C, OY + (SY + 0.1) * C, OX + (x + bx + .1) * C, OY + (SY + 0.28) * C], fill=(30, 30, 34, 255))
    if k != 'stove': R(x + 0.2, SY + 0.5, 0.6, 0.55, (214, 206, 192, 255), line=(150, 140, 128, 255), lw=2)
# tables with chairs
for (tx, ty) in [(SX + 1.2, SY + 2.3), (SX + 5.0, SY + 2.8), (SX + 1.3, SY + 4.0)]:
    R(tx - 0.35, ty + 0.3, 0.35, 0.35, (90, 130, 190, 255)); R(tx + 1.0, ty + 0.3, 0.35, 0.35, (90, 130, 190, 255))
    R(tx, ty, 1.0, 0.8, (178, 128, 84, 255))
    R(tx, ty + 0.62, 1.0, 0.18, (150, 104, 66, 255), line=None)
# door gap at the bottom of the shop (open front) and pots
d.rectangle([OX + (SX + 3) * C, OY + (SY + SH) * C - 6, OX + (SX + 5) * C, OY + (SY + SH) * C + 6], fill=(214, 170, 120, 255))
for (px, py) in [(SX + 0.2, SY + 0.6), (SX + 7.2, SY + 0.6), (SX + 7.1, SY + 4.0)]:
    R(px, py + 0.35, 0.5, 0.4, (196, 110, 70, 255)); d.ellipse([OX + px * C - 8, OY + py * C - 6, OX + (px + 0.5) * C + 8, OY + (py + 0.5) * C], fill=(60, 140, 70, 255), outline=OL, width=3)
# road along the top
d.rectangle([0, 0, im.width, OY - 2.2 * C + 2 * C - 90], fill=(110, 110, 118, 255))
d.rectangle([0, 0, im.width, 78], fill=(0, 0, 0, 190))
d.text((14, 8), 'ภาพจำลองมุมมอง Stardew (มองจากด้านบนเฉียง): ชิ้นส่วนชุดเดียวกันบนช่องสี่เหลี่ยม', font=fnt, fill=(255, 255, 255, 255))
d.text((14, 44), 'ผนังหลังเห็นด้านหน้า ผนังข้างบาง เคาน์เตอร์เป็นแถวตรง ไม่ต้องบิดเฉียง (รูปทรงเรียบๆ ไม่ใช่สไตล์จริง)', font=fs, fill=(255, 235, 150, 255))
im.convert('RGB').save(OUT)
print('ok')
