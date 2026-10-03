#!/usr/bin/env python3
"""Guide templates for the top-down (Stardew-style) art in docs/templates_td/. One cell = 128 px in the file (64 px in the game)."""
from PIL import Image, ImageDraw, ImageFont
import os
F = 'assets/fonts/NotoSansThai_400Regular.ttf'
OUT = 'docs/templates_td'
os.makedirs(OUT, exist_ok=True)
CY = (0, 170, 210, 255); MG = (255, 60, 150, 255); GR = (130, 130, 130, 255); YL = (255, 200, 0, 255)
def font(s): return ImageFont.truetype(F, s)
def new(w, h): return Image.new('RGBA', (w, h), (0, 0, 0, 0))
def note(d, w, title, lines):
    d.rectangle([2, 2, w - 3, 40 + len(lines) * 22], fill=(0, 0, 0, 170))
    d.text((8, 4), title, font=font(18), fill=(255, 255, 255, 255))
    for i, t in enumerate(lines): d.text((8, 30 + i * 22), t, font=font(15), fill=(255, 235, 150, 255))
def grid(d, w, h, step=128, col=GR):
    for x in range(0, w + 1, step): d.line([(x, 0), (x, h)], fill=col, width=1)
    for y in range(0, h + 1, step): d.line([(0, y), (w, y)], fill=col, width=1)
def save(im, name): im.save(f'{OUT}/{name}')

# tile: 128 x 128 opaque, seamless, no outline
im = new(128, 128); d = ImageDraw.Draw(im); grid(d, 128, 128)
d.rectangle([0, 0, 127, 127], outline=CY, width=2)
note(d, 128, 'พื้น 128x128', ['เต็มทั้งภาพ ไม่มีโปร่งใส', 'ต่อกันทุกทิศเนียน', 'ไม่มีเส้นขอบ'])
save(im, 'tpl_td_tile_128.png')
# wall: 128 x 256 per cell (2 cells tall), seamless left-right
im = new(128, 256); d = ImageDraw.Draw(im)
d.rectangle([0, 0, 127, 255], outline=GR, width=2)
for (y0, y1, t, c) in [(0, 24, 'บัวบน', YL), (24, 200, 'ตัวผนังเรียบ', CY), (200, 256, 'บัวล่าง', YL)]:
    d.rectangle([2, y0, 125, y1], outline=c, width=2); d.text((8, y0 + 4), t, font=font(14), fill=c)
d.line([(64, 0), (64, 256)], fill=MG, width=1)
note(d, 128, 'ผนังเรียบ 128x256', ['1 ช่องกว้าง 2 ช่องสูง', 'ซ้ายขวาต่อกันเนียน', 'ไม่มีเส้นตั้งที่ขอบ'])
save(im, 'tpl_td_wall_128x256.png')
# door: a separate 1 x 2 cell piece placed over a plain wall (the cell stays walkable in game)
im = new(128, 256); d = ImageDraw.Draw(im)
d.rectangle([0, 0, 127, 255], outline=GR, width=2); d.line([(64, 0), (64, 256)], fill=GR, width=1)
d.rectangle([14, 20, 114, 232], outline=CY, width=3); d.line([(0, 232), (127, 232)], fill=MG, width=1)
note(d, 128, 'ประตู 128x256', ['วางทับผนังเรียบ', 'ฐานอยู่เส้นชมพู', 'นอกกรอบโปร่งใส'])
save(im, 'tpl_td_door_128x256.png')
# low wall 128 x 64, side wall strip 32 x 256
im = new(128, 64); d = ImageDraw.Draw(im); d.rectangle([0, 0, 127, 63], outline=GR, width=2); d.rectangle([2, 2, 125, 16], outline=YL, width=2)
d.text((6, 22), 'ผนังเตี้ย 128x64', font=font(14), fill=(255, 255, 255, 255)); save(im, 'tpl_td_wall_low_128x64.png')
im = new(32, 256); d = ImageDraw.Draw(im); d.rectangle([0, 0, 31, 255], outline=GR, width=2); d.rectangle([2, 2, 29, 253], outline=CY, width=2)
d.text((2, 100), 'ผนัง\nข้าง\n32x256', font=font(12), fill=(255, 255, 255, 255)); save(im, 'tpl_td_wall_side_32x256.png')
# wall overlays 128 x 128: window / lamp / painting (placed on a plain wall)
def overlay(name, title, zone, col, lines):
    im = new(128, 128); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 127, 127], outline=GR, width=2); d.line([(64, 0), (64, 128)], fill=GR, width=1); d.line([(0, 104), (127, 104)], fill=MG, width=1)
    d.rectangle(zone, outline=col, width=3)
    d.rectangle([2, 2, 125, 20 + len(lines) * 15], fill=(0, 0, 0, 170)); d.text((6, 2), title, font=font(13), fill=(255, 255, 255, 255))
    for i, t in enumerate(lines): d.text((6, 18 + i * 15), t, font=font(11), fill=(255, 235, 150, 255))
    save(im, name)
overlay('tpl_td_window_128x128.png', 'หน้าต่าง 128x128', [16, 40, 112, 100], CY, ['วางทับผนังเรียบ', 'นอกกรอบโปร่งใส'])
overlay('tpl_td_wall_lamp_128x128.png', 'โคมไฟผนัง 128x128', [48, 40, 80, 100], MG, ['ติดระดับสายตา'])
overlay('tpl_td_wall_painting_128x128.png', 'ภาพวาด 128x128', [20, 40, 108, 100], MG, ['ขนาดตามกรอบ'])
# small props (tableware, utensils): 64 x 64
im = new(64, 64); d = ImageDraw.Draw(im); d.rectangle([0, 0, 63, 63], outline=GR, width=2); d.line([(32, 0), (32, 64)], fill=GR, width=1); d.line([(0, 52), (63, 52)], fill=MG, width=1)
d.rectangle([12, 16, 52, 46], outline=CY, width=2); d.text((6, 2), 'ของเล็ก 64x64', font=font(11), fill=(255, 255, 255, 255))
save(im, 'tpl_td_prop_64.png')
# furniture module 128 x 128: front view with the top strip visible; ends cut flush
im = new(128, 128); d = ImageDraw.Draw(im); grid(d, 128, 128)
d.rectangle([0, 0, 127, 127], outline=GR, width=2)
d.rectangle([0, 30, 127, 70], outline=YL, width=2); d.text((4, 40), 'ท็อป (เห็นจากด้านบน)', font=font(12), fill=YL)
d.rectangle([0, 70, 127, 127], outline=CY, width=2); d.text((4, 90), 'ตัวตู้ด้านหน้า', font=font(12), fill=CY)
d.line([(0, 30), (0, 127)], fill=MG, width=4); d.line([(127, 30), (127, 127)], fill=MG, width=4)
note(d, 128, 'โมดูล 128x128', ['ชนซ้ายขวาพอดี', 'ห้ามมีเส้นขอบ/เงา', 'ที่ขอบชมพู'])
save(im, 'tpl_td_module_128.png')
# object: n x m cells, base at the bottom, canvas = cells x 128
def obj(name, cw, ch, title):
    im = new(cw * 128, ch * 128); d = ImageDraw.Draw(im); grid(d, cw * 128, ch * 128)
    d.rectangle([0, 0, cw * 128 - 1, ch * 128 - 1], outline=GR, width=2)
    d.rectangle([2, (ch - 1) * 128, cw * 128 - 3, ch * 128 - 3], outline=CY, width=3)
    d.rectangle([2, 2, cw * 128 - 3, 62], fill=(0, 0, 0, 170)); d.text((6, 4), title, font=font(15), fill=(255, 255, 255, 255))
    d.text((6, 28), 'ฐาน (กรอบฟ้า) ชิดล่าง', font=font(13), fill=(255, 235, 150, 255))
    save(im, name)
obj('tpl_td_object_1x1.png', 1, 1, '1x1 128x128')
obj('tpl_td_object_2x1.png', 2, 1, '2x1 256x128')
obj('tpl_td_object_2x2.png', 2, 2, '2x2 256x256')
obj('tpl_td_tree_2x3.png', 2, 3, 'ต้นไม้ 256x384')
# icon 128
im = new(128, 128); d = ImageDraw.Draw(im); d.rectangle([0, 0, 127, 127], outline=GR, width=2); d.rectangle([8, 8, 119, 119], outline=CY, width=2)
d.text((12, 56), 'ไอคอน 128x128', font=font(14), fill=(255, 255, 255, 255)); save(im, 'tpl_td_icon_128.png')
print('ok')
