#!/usr/bin/env python3
"""Draws simple worked examples for docs/templates/examples/ (reference only, never loaded by the game)."""
from PIL import Image, ImageDraw, ImageFont
import math, random, os
S = 2
OUT = 'docs/templates/examples'
os.makedirs(OUT, exist_ok=True)
F = 'assets/fonts/NotoSansThai_400Regular.ttf'
OL = (62, 42, 30, 255)
GUIDE = (0, 190, 220, 255)

def new(w, h): return Image.new('RGBA', (w * S, h * S), (0, 0, 0, 0))
def P(pts): return [(x * S, y * S) for x, y in pts]
def poly(d, pts, fill, line=None, w=6):
    d.polygon(P(pts), fill=fill)
    if line: d.line(P(pts + [pts[0]]), fill=line, width=w * S)
def ell(d, cx, cy, rx, ry, fill, line=None, w=6):
    d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=fill, outline=line, width=w * S)
def done(im, name, caption, guide=None):
    out = im.resize((im.width // S, im.height // S), Image.LANCZOS)
    bg = Image.new('RGBA', out.size, (236, 228, 210, 255))
    if guide: bg.alpha_composite(guide)
    bg.alpha_composite(out)
    d = ImageDraw.Draw(bg)
    f = ImageFont.truetype(F, 30)
    w = d.textlength(caption, font=f)
    d.rectangle([20, 18, 20 + w + 20, 66], fill=(0, 0, 0, 170))
    d.text((30, 22), caption, font=f, fill=(255, 255, 255, 255))
    bg.convert('RGB').save(f'{OUT}/{name}')
def diamond_guide(w, h, cx, cy, size=1024):
    g = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(g)
    return g, d

# tree
g = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0)); gd = ImageDraw.Draw(g)
bw = 395; by = 1024 - bw / 4
gd.line([(512 - bw / 2, by), (512, by - bw / 4), (512 + bw / 2, by), (512, by + bw / 4), (512 - bw / 2, by)], fill=GUIDE, width=8)
im = new(1024, 1024); d = ImageDraw.Draw(im)
ell(d, 512, by + 10, 230, 70, (60, 80, 40, 120))
poly(d, [(480, by), (545, by), (555, 600), (470, 600)], (130, 90, 55, 255), OL)
for cx, cy, r, c in [(340, 480, 190, (70, 140, 60, 255)), (690, 470, 200, (70, 140, 60, 255)), (512, 330, 230, (84, 160, 70, 255)), (512, 520, 210, (62, 128, 56, 255))]:
    ell(d, cx, cy, r, r * 0.92, c, OL)
for cx, cy, r in [(430, 270, 90), (600, 330, 70)]:
    ell(d, cx, cy, r, r * 0.8, (110, 185, 90, 255))
done(im, 'example_tree.png', 'ตัวอย่างต้นไม้: โคนต้นตรงฐานสีฟ้า ใบอยู่ข้างบน', g)

# rock
bw = 790; by = 1024 - bw / 4
g = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0)); gd = ImageDraw.Draw(g)
gd.line([(512 - bw / 2, by), (512, by - bw / 4), (512 + bw / 2, by), (512, by + bw / 4), (512 - bw / 2, by)], fill=GUIDE, width=8)
im = new(1024, 1024); d = ImageDraw.Draw(im)
ell(d, 512, by + 40, 340, 110, (50, 60, 50, 110))
poly(d, [(190, 800), (230, 600), (360, 480), (540, 440), (700, 500), (810, 640), (840, 800), (700, 880), (400, 890)], (150, 150, 150, 255), OL)
poly(d, [(360, 480), (540, 440), (700, 500), (610, 600), (430, 610)], (190, 190, 188, 255))
poly(d, [(700, 500), (810, 640), (840, 800), (700, 880), (610, 600)], (115, 115, 118, 255))
done(im, 'example_rock.png', 'ตัวอย่างหิน: ด้านบนสว่าง ด้านขวามืด', g)

# bush
bw = 642; by = 1024 - bw / 4
g = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0)); gd = ImageDraw.Draw(g)
gd.line([(512 - bw / 2, by), (512, by - bw / 4), (512 + bw / 2, by), (512, by + bw / 4), (512 - bw / 2, by)], fill=GUIDE, width=8)
im = new(1024, 1024); d = ImageDraw.Draw(im)
ell(d, 512, by + 30, 300, 85, (50, 70, 40, 110))
for cx, cy, r in [(260, 760, 150), (760, 760, 150), (400, 650, 190), (640, 650, 190), (512, 800, 160)]:
    ell(d, cx, cy, r, r * 0.8, (66, 140, 70, 255), OL)
for cx, cy, r in [(420, 600, 70), (700, 620, 55)]:
    ell(d, cx, cy, r, r * 0.7, (105, 180, 95, 255))
for x, y in [(330, 700), (560, 740), (690, 700), (460, 650)]:
    ell(d, x, y, 16, 16, (220, 70, 70, 255))
done(im, 'example_bush.png', 'ตัวอย่างพุ่มไม้ (วางแปะติดพื้น กว้างกว่าสูง)', g)

# road tile: only inside the diamond, no outline
random.seed(4)
g = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0)); gd = ImageDraw.Draw(g)
gd.line([(0, 512), (512, 256), (1024, 512), (512, 768), (0, 512)], fill=GUIDE, width=6)
im = new(1024, 1024); d = ImageDraw.Draw(im)
mask = Image.new('L', im.size, 0)
ImageDraw.Draw(mask).polygon(P([(0, 512), (512, 256), (1024, 512), (512, 768)]), fill=255)
layer = Image.new('RGBA', im.size, (176, 138, 96, 255)); ld = ImageDraw.Draw(layer)
for _ in range(900):
    x, y = random.uniform(0, 1024), random.uniform(256, 768); r = random.uniform(3, 9)
    c = random.choice([(150, 112, 76, 255), (198, 160, 116, 255), (130, 100, 70, 255)])
    ld.ellipse([(x - r) * S, (y - r * 0.5) * S, (x + r) * S, (y + r * 0.5) * S], fill=c)
for off in (-120, 120):
    ld.line(P([(0, 512 + off * 0.5), (1024, 512 + off * 0.5)]), fill=(150, 114, 78, 255), width=26 * S)
im.paste(layer, (0, 0), mask)
done(im, 'example_tile_road.png', 'ตัวอย่างกระเบื้องถนน: เต็มข้าวหลามตัด ไม่มีเส้นขอบ', g)

# modules: counter / stove / counter in a row, run NW -> SE
H = 300
def module(d, ox, oy, kind):
    L, B, R = (ox, oy + 768), (ox + 512, oy + 1024), (ox + 1024, oy + 768)
    T = (ox + 512, oy + 512)
    Lt, Bt, Rt, Tt = (L[0], L[1] - H), (B[0], B[1] - H), (R[0], R[1] - H), (T[0], T[1] - H)
    body = (232, 226, 214, 255); body_d = (196, 190, 180, 255); top = (92, 100, 108, 255)
    poly(d, [Bt, R, B, Bt] if False else [Bt, Rt, R, B], body_d)  # SE end face (hidden by neighbour)
    poly(d, [Lt, Bt, B, L], body)  # long front face (SW)
    poly(d, [Lt, Tt, Rt, Bt], (118, 126, 134, 255) if kind != 'stove' else (70, 74, 80, 255))  # top
    d.line(P([L, B]), fill=OL, width=6 * S)  # bottom edge only
    d.line(P([Lt, Bt]), fill=OL, width=6 * S)  # front top edge
    d.line(P([Tt, Rt]), fill=OL, width=6 * S)  # back top edge
    # cabinet door on the front face
    def fp(u, v):  # u 0..1 along the face, v 0..1 up
        x = L[0] + (B[0] - L[0]) * u; y = L[1] + (B[1] - L[1]) * u - H * v
        return (x, y)
    if kind == 'counter':
        poly(d, [fp(.12, .12), fp(.88, .12), fp(.88, .86), fp(.12, .86)], (214, 206, 192, 255), (150, 140, 128, 255), 4)
        d.line(P([fp(.42, .74), fp(.58, .74)]), fill=(120, 120, 124, 255), width=8 * S)
    if kind == 'stove':
        poly(d, [fp(.12, .12), fp(.88, .12), fp(.88, .62), fp(.12, .62)], (60, 62, 68, 255), (150, 140, 128, 255), 4)
        poly(d, [fp(.2, .68), fp(.8, .68), fp(.8, .8), fp(.2, .8)], (214, 206, 192, 255))
        for u in (.3, .5, .7): d.ellipse([fp(u, .74)[0] * S - 9 * S, fp(u, .74)[1] * S - 9 * S, fp(u, .74)[0] * S + 9 * S, fp(u, .74)[1] * S + 9 * S], fill=(200, 80, 60, 255))
        for cx, cy in ((ox + 400, oy + 468), (ox + 624, oy + 468)):
            ell(d, cx, cy, 70, 34, (30, 30, 34, 255), (200, 200, 205, 255), 6)
g = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0)); gd = ImageDraw.Draw(g)
gd.line([(0, 768), (512, 512), (1024, 768), (512, 1024), (0, 768)], fill=GUIDE, width=6)
im = new(1024, 1024); d = ImageDraw.Draw(im); module(d, 0, 0, 'counter')
done(im, 'example_module_counter.png', 'ตัวอย่างเคาน์เตอร์ 1 ช่อง: ด้านซ้ายไม่มีขอบตั้ง', g)
im = new(2048, 1536); d = ImageDraw.Draw(im)
for i, k in enumerate(['counter', 'stove', 'counter']):
    module(d, 512 * i, 256 * i, k)
done(im, 'example_module_row.png', 'วางต่อกัน 3 ชิ้น: ท็อปเป็นเส้นเดียวต่อเนื่อง')

# window wall 512 x 840
im = new(512, 840); d = ImageDraw.Draw(im)
poly(d, [(0, 0), (512, 0), (512, 840), (0, 840)], (240, 228, 200, 255))
poly(d, [(0, 0), (512, 0), (512, 40), (0, 40)], (150, 100, 70, 255))
poly(d, [(0, 750), (512, 750), (512, 840), (0, 840)], (150, 100, 70, 255))
poly(d, [(160, 240), (352, 240), (352, 560), (160, 560)], (150, 210, 235, 255), OL, 8)
d.line(P([(256, 240), (256, 560)]), fill=OL, width=6 * S); d.line(P([(160, 400), (352, 400)]), fill=OL, width=6 * S)
poly(d, [(140, 560), (372, 560), (372, 590), (140, 590)], (150, 100, 70, 255), OL, 6)
g = Image.new('RGBA', (512, 840), (0, 0, 0, 0)); gd = ImageDraw.Draw(g)
gd.line([(0, 0), (0, 840)], fill=(255, 60, 150, 255), width=4); gd.line([(511, 0), (511, 840)], fill=(255, 60, 150, 255), width=4)
done(im, 'example_wall_window.png', 'ผนังหน้าต่าง: ซ้ายขวาไม่มีเส้นขอบ ต่อกันได้', g)
# wall overlay 256 x 840: window on its own, laid over a plain wall
im = new(256, 840); d = ImageDraw.Draw(im)
poly(d, [(40, 240), (216, 240), (216, 560), (40, 560)], (150, 210, 235, 255), OL, 8)
d.line(P([(128, 240), (128, 560)]), fill=OL, width=6 * S); d.line(P([(40, 400), (216, 400)]), fill=OL, width=6 * S)
poly(d, [(24, 560), (232, 560), (232, 590), (24, 590)], (150, 100, 70, 255), OL, 6)
g = Image.new('RGBA', (256, 840), (0, 0, 0, 0)); gd = ImageDraw.Draw(g)
gd.rectangle([0, 0, 255, 839], outline=GUIDE, width=3)
done(im, 'example_wall_overlay_window.png', 'หน้าต่างแยกชิ้น 256x840 (โปร่งใสรอบๆ)', g)
# plain wall 512 x 840
im = new(512, 840); d = ImageDraw.Draw(im)
poly(d, [(0, 0), (512, 0), (512, 840), (0, 840)], (240, 228, 200, 255))
for x in range(0, 512, 64): d.line(P([(x, 40), (x, 750)]), fill=(232, 219, 188, 255), width=2 * S)
poly(d, [(0, 0), (512, 0), (512, 40), (0, 40)], (150, 100, 70, 255))
poly(d, [(0, 750), (512, 750), (512, 840), (0, 840)], (150, 100, 70, 255))
d.line(P([(0, 750), (512, 750)]), fill=OL, width=5 * S)
d.line(P([(0, 40), (512, 40)]), fill=OL, width=5 * S)
g = Image.new('RGBA', (512, 840), (0, 0, 0, 0)); gd = ImageDraw.Draw(g)
gd.line([(256, 0), (256, 840)], fill=(255, 60, 150, 255), width=3)
done(im, 'example_wall_plain.png', 'ผนังเรียบ: ซ้ายขวาไม่มีเส้นขอบตั้ง', g)
print('ok')
