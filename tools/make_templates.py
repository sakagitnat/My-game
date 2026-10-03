#!/usr/bin/env python3
"""Draws the guide templates in docs/templates/ that the owner imports into a drawing app as a guide layer."""
from PIL import Image, ImageDraw, ImageFont
import glob, os
F = 'assets/fonts/NotoSansThai_400Regular.ttf'
OUT = 'docs/templates'
os.makedirs(OUT, exist_ok=True)
CY = (0, 190, 220, 255); MG = (255, 60, 150, 255); GR = (120, 120, 120, 200); YL = (255, 200, 0, 255)

def font(s): return ImageFont.truetype(F, s)

def diamond(d, cx, cy, w, h, col, width=6):
    pts = [(cx, cy - h / 2), (cx + w / 2, cy), (cx, cy + h / 2), (cx - w / 2, cy), (cx, cy - h / 2)]
    d.line(pts, fill=col, width=width)

def label(d, xy, text, size=34, col=(255, 255, 255, 255)):
    f = font(size); x, y = xy
    w = d.textlength(text, font=f)
    d.rectangle([x - 8, y - 4, x + w + 8, y + size + 8], fill=(0, 0, 0, 170))
    d.text((x, y), text, font=f, fill=col)

def canvas(w=1024, h=1024): return Image.new('RGBA', (w, h), (0, 0, 0, 0))

# 1. tile
im = canvas(); d = ImageDraw.Draw(im)
diamond(d, 512, 512, 1024, 512, CY, 8)
d.line([(0, 512), (1024, 512)], fill=GR, width=2); d.line([(512, 256), (512, 768)], fill=GR, width=2)
d.rectangle([0, 0, 1023, 1023], outline=GR, width=2)
label(d, (30, 30), "แม่แบบพื้น (tile) 1024 x 1024")
label(d, (30, 90), "วาดให้เต็มรูปข้าวหลามตัดสีฟ้า ห้ามล้นขอบ", 28)
label(d, (30, 135), "ไม่ต้องมีเส้นขอบที่ขอบข้าวหลามตัด ต่อกันทุกทิศต้องเนียน", 28)
label(d, (30, 950), "ซ่อนเลเยอร์นี้ก่อนส่งออก PNG พื้นหลังโปร่งใส", 28, (255, 220, 100, 255))
im.save(f'{OUT}/tpl_tile_1024.png')

# 2. obstacles: the one-cell diamond sits at the bottom centre, width = 64 / in-game width * 1024
def obstacle(name, title, cells_w, tip):
    im = canvas(); d = ImageDraw.Draw(im)
    w = 64.0 / (cells_w * 64.0) * 1024
    diamond(d, 512, 1024 - w / 4, w, w / 2, CY, 8)
    d.rectangle([51, 51, 972, 972], outline=GR, width=2)
    d.line([(512, 0), (512, 1024)], fill=GR, width=2)
    label(d, (30, 30), title)
    label(d, (30, 90), "ฐานโคนต้อง (สีฟ้า) อยู่กึ่งกลางล่างของภาพ", 28)
    label(d, (30, 135), tip, 28)
    label(d, (30, 180), "เงาใต้ต้นให้วาดรวมในไฟล์เดียวกัน ภาพอยู่ในกรอบเทา", 28)
    im.save(f'{OUT}/{name}')
obstacle('tpl_tree.png', 'แม่แบบต้นไม้ (obs_tree_xx)', 2.6, 'ในเกมกว้าง 2.6 ช่อง ฐานสีฟ้าคือ 1 ช่อง')
obstacle('tpl_rock.png', 'แม่แบบก้อนหิน (obs_rock_xx)', 1.3, 'ในเกมกว้าง 1.3 ช่อง ฐานสีฟ้าคือ 1 ช่อง')
obstacle('tpl_bush.png', 'แม่แบบพุ่มไม้ (obs_bush_xx)', 1.6, 'ในเกมกว้าง 1.6 ช่อง ฐานสีฟ้าคือ 1 ช่อง')

# 3. furniture / objects bottom-aligned, base fills the canvas width
for n in (1, 2, 3):
    im = canvas(); d = ImageDraw.Draw(im)
    diamond(d, 512, 768, 1024, 512, CY, 8)
    for k in range(1, n):
        t = k / n
        d.line([(512 - 512 * t, 768 - 256 * t), (1024 - 512 * t, 512 + 256 * (1 - t) * 0 + 256 * 0 + 0)], fill=(0, 0, 0, 0), width=1)
    d.line([(512, 0), (512, 1024)], fill=GR, width=2)
    d.rectangle([0, 0, 1023, 1023], outline=GR, width=2)
    label(d, (30, 30), f"แม่แบบวัตถุ {n}x{n} ช่อง")
    label(d, (30, 90), "ฐานวัตถุต้องเต็มรูปข้าวหลามตัดสีฟ้า ชิดล่างกึ่งกลาง", 28)
    label(d, (30, 135), "ถ้าฐานแคบกว่านี้ วัตถุจะลอยเหนือพื้นในเกม", 28)
    im.save(f'{OUT}/tpl_object_{n}x{n}.png')

# 4. wall modules
def wall(name, w, h, title, zones):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w - 1, h - 1], outline=GR, width=3)
    d.line([(w // 2, 0), (w // 2, h)], fill=MG, width=3)
    for (y0, y1, txt, col) in zones:
        d.rectangle([4, y0, w - 5, y1], outline=col, width=3)
        d.text((14, y0 + 6), txt, font=font(24), fill=col)
    d.text((14, 8), title, font=font(28), fill=(255, 255, 255, 255))
    im.save(f'{OUT}/{name}')
wall('tpl_wall_512x840.png', 512, 840, 'ผนังเรียบ 512 x 840 (กว้าง 2 ช่อง)', [
    (0, 40, 'ขอบบน (บัวบน)', YL), (40, 750, 'ตัวผนังเรียบ ไม่มีหน้าต่าง/โคมไฟ/ภาพวาด', CY), (750, 840, 'บัวผนังล่าง (ชิดขอบล่างภาพ)', YL)])
wall('tpl_wall_low_512x112.png', 512, 112, 'ผนังเตี้ย 512 x 112', [(0, 24, 'ขอบบน', YL)])
d2 = ImageDraw.Draw(Image.new('RGBA', (1, 1)))
for n in ('tpl_wall_512x840.png', 'tpl_wall_low_512x112.png'):
    im = Image.open(f'{OUT}/{n}'); d = ImageDraw.Draw(im)
    d.text((14, im.height - 40 if im.height > 200 else 60), 'เส้นชมพูกลางภาพ = รอยต่อระหว่างช่อง', font=font(24), fill=MG)
    im.save(f'{OUT}/{n}')

# 4b. furniture set module: 1x1 box, run direction NW -> SE, top surface raised by HEIGHT px
HEIGHT = 300
im = canvas(); d = ImageDraw.Draw(im)
diamond(d, 512, 768, 1024, 512, CY, 8)
diamond(d, 512, 768 - HEIGHT, 1024, 512, YL, 6)
for x, y in ((0, 768), (512, 1024), (1024, 768)):
    d.line([(x, y), (x, y - HEIGHT)], fill=YL, width=6)
d.line([(0, 768), (512, 512)], fill=MG, width=10)
d.line([(0, 768 - HEIGHT), (512, 512 - HEIGHT)], fill=MG, width=10)
d.line([(512, 1024), (1024, 768)], fill=GR, width=4)
d.rectangle([0, 0, 1023, 1023], outline=GR, width=2)
label(d, (30, 30), "แม่แบบโมดูลเฟอร์นิเจอร์ 1x1 (ชุดต่อกันได้)")
label(d, (30, 90), "ฟ้า = ฐาน 1 ช่อง  เหลือง = กล่องความสูง 300 px", 28)
label(d, (30, 135), "ชมพู = ขอบปลายซ้าย (NW) ที่ต่อกับชิ้นถัดไป ภาพต้องชนเส้นนี้พอดี", 28)
label(d, (30, 180), "ห้ามมีเส้นขอบ เงา หรือเสาที่ปลายต่อ ท็อปสูงเท่ากันทุกชิ้นในชุด", 28)
label(d, (30, 950), "ซ่อนเลเยอร์นี้ก่อนส่งออก PNG พื้นหลังโปร่งใส", 28, (255, 220, 100, 255))
im.save(f'{OUT}/tpl_module_1x1.png')

# 4c. wall overlay: one cell wide, same height as the wall; window / lamp / painting
im = Image.new('RGBA', (256, 840), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
d.rectangle([0, 0, 255, 839], outline=GR, width=3)
d.line([(128, 0), (128, 840)], fill=GR, width=1)
for (y0, y1, txt, col) in [(0, 40, 'ขอบบน', YL), (200, 560, 'หน้าต่าง/ภาพวาด', CY), (250, 330, 'โคมไฟ', MG), (750, 840, 'บัวผนังล่าง', YL)]:
    d.rectangle([4, y0, 251, y1], outline=col, width=2)
    d.text((10, y0 + 4), txt, font=font(18), fill=col)
d.text((10, 8), 'ซ้อนบนผนังเรียบ 256x840', font=font(18), fill=(255, 255, 255, 255))
d.text((10, 600), 'วาดเฉพาะของที่ติดผนัง', font=font(18), fill=(255, 255, 255, 255))
d.text((10, 628), 'นอกนั้นโปร่งใส', font=font(18), fill=(255, 255, 255, 255))
im.save(f'{OUT}/tpl_wall_overlay_256x840.png')

# 4d. door piece, window / lamp / painting overlays, flat rug
def sized(w, h): return Image.new('RGBA', (w, h), (0, 0, 0, 0))
def frame(d, w, h, title, lines, seam=None):
    d.rectangle([0, 0, w - 1, h - 1], outline=GR, width=3)
    if seam: d.line([(seam, 0), (seam, h)], fill=MG, width=3)
    d.rectangle([4, 4, w - 5, 44 + len(lines) * 26], fill=(0, 0, 0, 170))
    d.text((10, 8), title, font=font(24), fill=(255, 255, 255, 255))
    for i, t in enumerate(lines): d.text((10, 44 + i * 26), t, font=font(18), fill=(255, 235, 150, 255))
# door: two cells wide, opening in the middle must be fully transparent down to the bottom edge
im = sized(512, 840); d = ImageDraw.Draw(im)
frame(d, 512, 840, 'ประตู 512 x 840 (wall_door_01)', ['ช่องกลาง (ฟ้า) เจาะโปร่งใสถึงขอบล่างภาพ', 'ผนังซ้ายขวาของช่องวาดเหมือนผนังเรียบ', 'กรอบประตู + คานบน เป็นส่วนของภาพ'], 256)
d.rectangle([128, 200, 384, 840], outline=CY, width=4); d.text((150, 600), 'ช่องประตู (โปร่งใส)', font=font(22), fill=CY)
d.rectangle([0, 0, 511, 40], outline=YL, width=2); d.rectangle([0, 750, 511, 839], outline=YL, width=2)
im.save(f'{OUT}/tpl_door_512x840.png')
def overlay(name, title, lines, zone, zcol, extra=None):
    im = sized(256, 840); d = ImageDraw.Draw(im)
    frame(d, 256, 840, title, lines, 128)
    d.rectangle(zone, outline=zcol, width=4)
    if extra: extra(d)
    im.save(f'{OUT}/{name}')
overlay('tpl_window_256x840.png', 'หน้าต่าง 256 x 840', ['กรอบฟ้า = ตัวหน้าต่าง', 'พื้นที่อื่นโปร่งใส', 'ซ้อนบนผนังเรียบ'], [30, 230, 226, 580], CY,
        lambda d: d.rectangle([20, 575, 236, 600], outline=YL, width=2))
overlay('tpl_wall_lamp_256x840.png', 'โคมไฟติดผนัง 256 x 840', ['กรอบชมพู = ตัวโคม', 'ติดสูงระดับสายตา', 'พื้นที่อื่นโปร่งใส'], [88, 250, 168, 380], MG)
overlay('tpl_wall_painting_256x840.png', 'ภาพวาดติดผนัง 256 x 840', ['กรอบชมพู = กรอบภาพ', 'ใหญ่เล็กได้ในกรอบนี้', 'พื้นที่อื่นโปร่งใส'], [40, 230, 216, 450], MG)
# rug: flat on the 2x2 base diamond (bottom aligned, canvas width = footprint width)
im = canvas(); d = ImageDraw.Draw(im)
diamond(d, 512, 768, 1024, 512, CY, 8)
d.line([(512, 512), (512, 1024)], fill=GR, width=2)
d.rectangle([0, 0, 1023, 1023], outline=GR, width=2)
label(d, (30, 30), "แม่แบบพรมปูพื้น 2x2 ช่อง (deco_rug_01)")
label(d, (30, 90), "ภาพแบน วาดอยู่ในกรอบข้าวหลามตัดสีฟ้า ไม่ตั้งขึ้น ไม่มีเงา", 28)
label(d, (30, 135), "ขอบพรมมนหรือหยักได้ในกรอบ นอกกรอบโปร่งใส", 28)
im.save(f'{OUT}/tpl_rug_2x2.png')

# 5. icon
im = canvas(256, 256); d = ImageDraw.Draw(im)
d.rectangle([0, 0, 255, 255], outline=GR, width=3); d.rectangle([16, 16, 239, 239], outline=CY, width=3)
d.line([(128, 0), (128, 256)], fill=GR, width=1); d.line([(0, 128), (256, 128)], fill=GR, width=1)
d.text((24, 100), "ไอคอน 256x256 ภาพตรงหน้า", font=font(20), fill=(255, 255, 255, 255))
im.save(f'{OUT}/tpl_icon_256.png')

# 6. style sheet from the art that already exists
files = sorted(glob.glob('assets/restaurant/*.png')) + [f'assets/tiles/{n}.png' for n in ('tile_grass_01', 'tile_sand_01', 'tile_wood_floor_01', 'tile_path_stone_01', 'tile_water_01')]
cols = 4; cell = 320
rows = (len(files) + cols - 1) // cols
sheet = Image.new('RGBA', (cols * cell, rows * (cell + 30)), (236, 228, 210, 255))
sd = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    im = Image.open(f).convert('RGBA').resize((cell, cell), Image.LANCZOS)
    x, y = (i % cols) * cell, (i // cols) * (cell + 30)
    sheet.alpha_composite(im, (x, y))
    sd.text((x + 8, y + cell + 4), os.path.basename(f), font=font(18), fill=(40, 30, 20, 255))
sheet.convert('RGB').save(f'{OUT}/style_sheet_existing_art.png')
print('ok')
