#!/usr/bin/env python3
"""Builds the Salvora Set Workshop: the template sheet (guide + blank PNG + layout) and assets/td/art_workshop/index.html.
Run from the repo root: python3 tools/workshop/build.py"""
import sys, os, json, base64, io, glob
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw, ImageFont
from items import ITEMS, CATEGORIES, anchor

SHEET_W = 1920
M = 32          # sheet margin
GUT = 28        # gap between cells
LABEL_H = 58
HEAD_H = 52
FONT = 'assets/fonts/NotoSansThai_400Regular.ttf'
OUT = 'assets/td/art_workshop'
CY = (45, 170, 192, 255); BL = (44, 106, 172, 255); PK = (224, 88, 120, 255); GN = (50, 157, 114, 255); MG = (236, 64, 150, 255)

def layout():
    out = []; x = M; y = M + 70; row_h = 0; heads = []
    for cat in CATEGORIES:
        its = [i for i in ITEMS if i[5] == cat]
        if x > M:
            y += row_h; x = M; row_h = 0
        heads.append((cat, y)); y += HEAD_H
        for (id_, folder, file, w, h, c, label, hint, flags) in its:
            cw = max(w, 184)
            if x + cw > SHEET_W - M:
                y += row_h; x = M; row_h = 0
            out.append(dict(id=id_, folder=folder, file=file, w=w, h=h, x=x + (cw - w) // 2, y=y + LABEL_H, category=c, label=label, hint=hint, flags=flags, anchor=list(anchor(w, h))))
            x += cw + GUT; row_h = max(row_h, LABEL_H + h + GUT)
        y += row_h; x = M; row_h = 0
    return out, heads, y + M

SHAPES = {
    'wallplain': [('r', 0, 0, 127, 24), ('r', 0, 24, 127, 200), ('r', 0, 200, 127, 255)],
    'walllow': [('r', 0, 8, 127, 56)],
    'wallside': [('r', 3, 3, 28, 252)],
    'window': [('r', 16, 40, 112, 100), ('l', 64, 40, 64, 100), ('l', 16, 70, 112, 70)],
    'door': [('r', 14, 20, 114, 232), ('r', 24, 32, 104, 220)],
    'dooropen': [('r', 14, 20, 114, 232), ('r', 24, 32, 104, 220), ('l', 24, 32, 44, 40), ('l', 44, 40, 44, 212), ('l', 44, 212, 24, 220)],
    'lamp': [('r', 48, 44, 80, 100), ('l', 64, 30, 64, 44)],
    'painting': [('r', 20, 36, 108, 100), ('r', 28, 44, 100, 92)],
    'hood': [('r', 20, 30, 108, 96), ('r', 40, 50, 88, 96)],
    'module': [('r', 0, 30, 'W', 58), ('r', 0, 58, 'W', 104)],
    'fridge': [('r', 14, 24, 114, 232), ('l', 14, 100, 114, 100)],
    'table': [('r', 10, 30, 'W-10', 104), ('r', 10, 84, 'W-10', 104)],
    'chair': [('r', 36, 34, 92, 100), ('r', 36, 34, 92, 54)],
    'stool': [('e', 64, 70, 30, 22)],
    'register': [('r', 24, 40, 104, 104), ('r', 36, 48, 92, 70)],
    'shelf': [('r', 12, 24, 116, 232), ('l', 12, 90, 116, 90), ('l', 12, 160, 116, 160)],
    'sign': [('r', 30, 20, 98, 104)],
    'plant': [('e', 64, 52, 32, 28), ('r', 46, 80, 82, 104)],
    'rug': [('r', 16, 90, 'W-16', 'H-30')],
    'floorlamp': [('r', 52, 20, 76, 232), ('e', 64, 36, 24, 18)],
    'bin': [('r', 34, 36, 94, 104)],
    'crate': [('r', 20, 34, 108, 104), ('l', 20, 34, 108, 104)],
    'prop': [('e', 'W/2', 'H/2', 18, 12)],
}
def ev(v, w, h):
    return int(eval(str(v), {}, {'W': w - 1, 'H': h})) if isinstance(v, str) else v

def draw_guide(items, heads, H, S, background=True):
    im = Image.new('RGBA', (SHEET_W * S, H * S), (240, 244, 241, 255) if background else (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    f1 = ImageFont.truetype(FONT, 15 * S); f2 = ImageFont.truetype(FONT, 11 * S); fh = ImageFont.truetype(FONT, 26 * S); ft = ImageFont.truetype(FONT, 18 * S)
    d.text((M * S, 18 * S), 'ชุดเซ็ต Salvora — วาดทับแม่แบบนี้ แล้ว "ซ่อนเลเยอร์แม่แบบ" ก่อนส่งออก PNG', font=fh, fill=(23, 60, 54, 255))
    d.text((M * S, 52 * S), 'เส้นฟ้า = กรอบภาพ (1 ช่อง = 128 px)  เส้นชมพู = ฐานวัตถุ  กากบาทเขียว = จุดวาง  เส้นแดงที่ขอบ = ต้องชนขอบพอดี', font=ft, fill=(99, 117, 110, 255))
    for cat, y in heads:
        d.rectangle([M * S, y * S, (SHEET_W - M) * S, (y + 40) * S], fill=(210, 228, 222, 255))
        d.text(((M + 10) * S, (y + 6) * S), cat, font=fh, fill=(23, 60, 54, 255))
    for it in items:
        x, y, w, h = it['x'] * S, it['y'] * S, it['w'] * S, it['h'] * S
        d.text((x, y - 54 * S), it['label'], font=f1, fill=(23, 60, 54, 255))
        d.text((x, y - 34 * S), it['file'], font=f2, fill=(99, 117, 110, 255))
        d.text((x, y - 19 * S), f"{it['w']}x{it['h']} px", font=f2, fill=(99, 117, 110, 255))
        d.rectangle([x, y, x + w - 1, y + h - 1], outline=CY, width=2 * S, fill=(255, 255, 255, 255) if background else None)
        for cx in range(1, it['w'] // 128): d.line([(x + cx * 128 * S, y), (x + cx * 128 * S, y + h)], fill=(45, 170, 192, 110), width=S)
        for cy in range(1, it['h'] // 128): d.line([(x, y + cy * 128 * S), (x + w, y + cy * 128 * S)], fill=(45, 170, 192, 110), width=S)
        ax, ay = it['anchor']
        d.line([(x, y + ay * S), (x + w, y + ay * S)], fill=(*PK[:3], 140), width=S)
        d.line([(x + (ax - 6) * S, y + ay * S), (x + (ax + 6) * S, y + ay * S)], fill=GN, width=2 * S)
        d.line([(x + ax * S, y + (ay - 6) * S), (x + ax * S, y + (ay + 6) * S)], fill=GN, width=2 * S)
        for sh in SHAPES.get(it['hint'], []):
            k = sh[0]; a = [ev(v, it['w'], it['h']) for v in sh[1:]]
            if k == 'r': d.rectangle([x + a[0] * S, y + a[1] * S, x + a[2] * S, y + a[3] * S], outline=BL, width=2 * S)
            elif k == 'e': d.ellipse([x + (a[0] - a[2]) * S, y + (a[1] - a[3]) * S, x + (a[0] + a[2]) * S, y + (a[1] + a[3]) * S], outline=BL, width=2 * S)
            else: d.line([x + a[0] * S, y + a[1] * S, x + a[2] * S, y + a[3] * S], fill=BL, width=2 * S)
        fl = it['flags']
        if 'flush' in fl or 'flushl' in fl:
            d.line([(x, y + 30 * S), (x, y + h)], fill=MG, width=3 * S) if it['hint'] in ('module',) else None
        if it['hint'] == 'module':
            if fl in ('flush', 'flushr'): d.line([(x, y + 30 * S), (x, y + 104 * S)], fill=MG, width=3 * S)
            if fl in ('flush', 'flushl'): d.line([(x + w - 2 * S, y + 30 * S), (x + w - 2 * S, y + 104 * S)], fill=MG, width=3 * S)
        if it['hint'] in ('wallplain', 'walllow'):
            d.line([(x, y), (x, y + h)], fill=MG, width=3 * S); d.line([(x + w - 2 * S, y), (x + w - 2 * S, y + h)], fill=MG, width=3 * S)
    return im

def png_uri(im):
    b = io.BytesIO(); im.save(b, 'PNG', optimize=True); return 'data:image/png;base64,' + base64.b64encode(b.getvalue()).decode()

if __name__ == '__main__':
    items, heads, H = layout()
    g1 = draw_guide(items, heads, H, 1); g2 = draw_guide(items, heads, H, 2)
    blank = Image.new('RGBA', (SHEET_W, H), (0, 0, 0, 0))
    lay = {'sheetW': SHEET_W, 'sheetH': H, 'items': items, 'categories': CATEGORIES}
    tpl = open('tools/workshop/template.html', encoding='utf-8').read()
    html = tpl.replace('__LAYOUT__', json.dumps(lay, ensure_ascii=False)).replace('__GUIDE1__', png_uri(g1)).replace('__GUIDE2__', png_uri(g2)).replace('__BLANK__', png_uri(blank))
    os.makedirs(OUT, exist_ok=True)
    for old in glob.glob(f'{OUT}/*.zip') + [f'{OUT}/preview.png']:
        if os.path.exists(old): os.remove(old)
    open(f'{OUT}/index.html', 'w', encoding='utf-8').write(html)
    g1.convert('RGB').save(f'{OUT}/set_template_guide.png'); g2.convert('RGB').save(f'{OUT}/set_template_guide_2x.png')
    blank.save(f'{OUT}/set_template_blank.png'); json.dump(lay, open(f'{OUT}/set_template_layout.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    rows = ['# ชุดเซ็ต (Set v1): 45 ชิ้นที่ชุดหนึ่งต้องมี', '', 'สร้างอัตโนมัติจาก `tools/workshop/items.py` ด้วย `python3 tools/workshop/build.py` อย่าแก้มือ เว็บ Art Workshop (`/art-workshop/`) ใช้รายการนี้ ชื่อไฟล์ตรงกับที่เกมโหลด (`assets/td/<โฟลเดอร์>/<ชื่อ>.png`)', '', '| หมวด | ชื่อ | โฟลเดอร์ | ไฟล์ | ขนาด (px) | หมายเหตุ |', '|---|---|---|---|---|---|']
    note = {'tile': 'ทึบ ต่อกันทุกทิศ', 'flush': 'ปลายซ้ายขวาชนขอบภาพ', 'flushr': 'ปลายซ้ายชนขอบ', 'flushl': 'ปลายขวาชนขอบ', 'flat': 'ภาพแบนบนพื้น', '': ''}
    for it in items:
        rows.append(f"| {it['category']} | {it['label']} | `{it['folder']}` | `{it['file']}.png` | {it['w']}x{it['h']} | {note.get(it['flags'], '')} |")
    rows += ['', 'ฐาน (anchor): สูงจากขอบล่าง 24 px สำหรับภาพ 128 px (12 px สำหรับของเล็ก 64 px) กึ่งกลางแนวนอน หน้าต่างติดสูงจากพื้นผนัง 70 px (ในเกม) ประตูอยู่บนพื้น']
    open('docs/ART_SET.md', 'w', encoding='utf-8').write('\n'.join(rows) + '\n')
    print('items', len(items), 'sheet', SHEET_W, H, 'html', len(html))
