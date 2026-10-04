#!/usr/bin/env python3
"""Builds the Salvora Set Workshop: the template sheet (guide + blank PNG + layout) and assets/td/art_workshop/index.html.
Run from the repo root: python3 tools/workshop/build.py"""
import sys, os, json, base64, io, glob
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw, ImageFont
from items import ITEMS, CATEGORIES, SHEETS, WALL_DECO, anchor

SHEET_W = 1920
M = 32          # sheet margin
GUT = 28        # gap between cells
LABEL_H = 58
HEAD_H = 52
FONT = 'assets/fonts/NotoSansThai_400Regular.ttf'
OUT = 'assets/td/art_workshop'
CY = (45, 170, 192, 255); BL = (44, 106, 172, 255); PK = (224, 88, 120, 255); GN = (50, 157, 114, 255); MG = (236, 64, 150, 255)

def layout(sheet):
    """Positions of the pieces of one sheet: (items, heads, height)."""
    out = []; x = M; y = M + 70; row_h = 0; heads = []
    for cat in sheet['categories']:
        its = [i for i in ITEMS if i[5] == cat]
        if x > M:
            y += row_h; x = M; row_h = 0
        heads.append((cat, y)); y += HEAD_H
        for (id_, folder, file, w, h, c, label, hint, flags) in its:
            cw = max(w, 150 if hint == 'char' else 184)
            if x + cw > SHEET_W - M:
                y += row_h; x = M; row_h = 0
            out.append(dict(id=id_, folder=folder, file=file, w=w, h=h, x=x + (cw - w) // 2, y=y + LABEL_H, category=c, label=label, hint=hint, flags=flags, anchor=list(anchor(w, h, hint)), sheet=sheet['id'], status=sheet['status']))
            x += cw + GUT; row_h = max(row_h, LABEL_H + h + GUT)
        y += row_h; x = M; row_h = 0
    return out, heads, y + M

SHAPES = {
    'wallplain': [('r', 0, 0, 127, 24), ('r', 0, 24, 127, 330), ('r', 0, 330, 127, 383)],
    'walllow': [('r', 0, 8, 127, 56)],
    'wallside': [('r', 3, 3, 28, 380)],
    'window': [('r', 16, 40, 112, 100), ('l', 64, 40, 64, 100), ('l', 16, 70, 112, 70)],
    'door': [('r', 14, 20, 114, 232), ('r', 24, 32, 104, 220)],
    'dooropen': [('r', 14, 20, 114, 232), ('r', 24, 32, 104, 220), ('l', 24, 32, 44, 40), ('l', 44, 40, 44, 212), ('l', 44, 212, 24, 220)],
    'lamp': [('r', 48, 44, 80, 100), ('l', 64, 30, 64, 44)],
    'painting': [('r', 20, 36, 108, 100), ('r', 28, 44, 100, 92)],
    'hood': [('r', 20, 30, 108, 96), ('r', 40, 50, 88, 96)],
    # things on the floor fill the cell they stand in: the top surface at the back, the front face down to the floor
    'module': [('r', 0, 2, 'W', 62), ('r', 0, 62, 'W', 188)],
    'fridge': [('r', 10, 4, 118, 64), ('r', 10, 64, 118, 316), ('l', 10, 150, 118, 150)],
    'table': [('r', 4, 8, 'W-4', 68), ('r', 8, 68, 'W-8', 122)],
    'chair': [('r', 34, 10, 94, 90), ('r', 30, 90, 98, 140), ('r', 34, 140, 94, 188)],
    'tablelong': [('r', 4, 4, 'W-4', 64), ('r', 8, 64, 'W-8', 188)],
    'stool': [('e', 64, 62, 34, 18), ('l', 40, 76, 34, 122), ('l', 88, 76, 94, 122)],
    'register': [('r', 10, 62, 118, 188), ('r', 30, 10, 98, 64)],
    'shelf': [('r', 8, 10, 120, 316), ('l', 8, 110, 120, 110), ('l', 8, 210, 120, 210)],
    'sign': [('r', 26, 16, 102, 184)],
    'plant': [('e', 64, 84, 50, 62), ('r', 38, 160, 90, 250)],
    'rug': [('r', 6, 6, 'W-6', 'H-6'), ('r', 18, 18, 'W-18', 'H-18')],
    'floorlamp': [('r', 44, 8, 84, 60), ('r', 60, 60, 68, 300), ('e', 64, 308, 30, 8)],
    'bin': [('r', 34, 40, 94, 122)],
    'crate': [('r', 14, 34, 114, 122), ('l', 14, 34, 114, 122)],
    'prop': [('e', 'W/2', 'H/2', 18, 12)],
    'vase': [('e', 'W/2', 44, 26, 30), ('r', 44, 72, 84, 122)],
    # the game's table and stove take 2 x 2 cells: top surface at the back (about 6%..55% of the depth), front face down to the floor
    'table2': [('r', 8, 4, 'W-8', 128), ('r', 16, 128, 'W-16', 252)],
    'stove2': [('r', 8, 4, 'W-8', 128), ('r', 16, 128, 'W-16', 252), ('e', 80, 64, 22, 14), ('e', 176, 64, 22, 14)],
    # outdoors and farm
    'tree': [('e', 'W/2', 130, 100, 100), ('r', 114, 230, 142, 378), ('e', 'W/2', 378, 40, 10)],
    'rock': [('e', 'W/2', 60, 48, 30)],
    'bush': [('e', 'W/2', 58, 50, 32)],
    'soil': [('r', 10, 10, 'W-10', 'H-10')],
    'crop1': [('e', 'W/2', 214, 14, 16)], 'crop2': [('e', 'W/2', 200, 30, 36)],
    'crop3': [('e', 'W/2', 188, 44, 56)], 'crop4': [('e', 'W/2', 178, 56, 70)],
    'fence': [('r', 8, 40, 'W-8', 150), ('r', 54, 20, 74, 156)],
    'coop': [('r', 8, 20, 'W-8', 170), ('r', 24, 170, 'W-24', 440)],
    'icon': [('e', 'W/2', 'H/2', 46, 46)],
    'char': [('e', 'W/2', 50, 26, 26), ('r', 42, 80, 86, 180), ('r', 46, 180, 82, 250)],
    # soft ground edges: the band (or corner) of the neighbouring ground that reaches into the cell; paint it fading out inwards
    'edge_n': [('r', 0, 0, 127, 50)], 'edge_s': [('r', 0, 77, 127, 127)],
    'edge_w': [('r', 0, 0, 50, 127)], 'edge_e': [('r', 77, 0, 127, 127)],
    'corner_nw': [('r', 0, 0, 50, 50)], 'corner_ne': [('r', 77, 0, 127, 50)],
    'corner_sw': [('r', 0, 77, 50, 127)], 'corner_se': [('r', 77, 77, 127, 127)],
}
FLOOR_HINTS = ('module', 'fridge', 'table', 'chair', 'stool', 'register', 'shelf', 'sign', 'plant', 'rug', 'floorlamp', 'bin', 'crate', 'prop', 'tablelong', 'table2', 'stove2', 'vase', 'tree', 'rock', 'bush', 'crop1', 'crop2', 'crop3', 'crop4', 'fence', 'coop')
# how deep (px) and how wide the dashed floor marker is for pieces that are not one cell
FOOT_DEPTH = {'coop': 384, 'rug': None, 'prop': None, 'vase': None, 'rock': None, 'bush': None, 'table2': 256, 'stove2': 256, 'crop1': 256, 'crop2': 256, 'crop3': 256, 'crop4': 256}
FOOT_WIDTH = {'tree': 128, 'rock': 128, 'bush': 128}
def ev(v, w, h):
    return int(eval(str(v), {}, {'W': w - 1, 'H': h})) if isinstance(v, str) else v

def draw_guide(items, heads, H, S, title, background=True):
    im = Image.new('RGBA', (SHEET_W * S, H * S), (240, 244, 241, 255) if background else (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    f1 = ImageFont.truetype(FONT, 15 * S); f2 = ImageFont.truetype(FONT, 11 * S); fh = ImageFont.truetype(FONT, 26 * S); ft = ImageFont.truetype(FONT, 18 * S)
    d.text((M * S, 18 * S), f'Salvora — {title} — วาดทับแม่แบบนี้ แล้ว "ซ่อนเลเยอร์แม่แบบ" ก่อนส่งออก PNG', font=fh, fill=(23, 60, 54, 255))
    d.text((M * S, 52 * S), 'เส้นฟ้า = กรอบภาพ (1 ช่อง = 128 px)  เส้นประเขียว = ช่องที่ของกิน (ตัวของต้องเต็มช่องนี้ ชิดขอบล่างและขอบหลัง)  เส้นแดงที่ขอบ = ต้องชนขอบพอดี', font=ft, fill=(99, 117, 110, 255))
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
        guide = piece_guide(it['id'])
        if guide is not None:
            gw, gh = guide.size
            if it['flags'] in ('tile', 'flat'):
                scale = None; tw, th = it['w'] * S, it['h'] * S
            else:
                room_w, room_h = (it['w'] - 12) * S, (it['anchor'][1] - 6) * S if it['hint'] in WALL_DECO else (it['h'] - 12) * S
                k = min(room_w / gw, room_h / gh); tw, th = max(1, int(gw * k)), max(1, int(gh * k))
            g2 = guide.resize((tw, th), Image.LANCZOS)
            g2.putalpha(g2.getchannel('A').point(lambda v: int(v * 0.7)))
            gx = x + (it['w'] * S - tw) // 2
            gy = y + (it['h'] * S - th - 6 * S if it['flags'] not in ('tile', 'flat') and it['hint'] not in WALL_DECO else (y + it['anchor'][1] * S - th - 6 * S if it['hint'] in WALL_DECO else y))
            gy = int(gy) if it['flags'] not in ('tile', 'flat') else y
            im.alpha_composite(g2, (int(gx), int(gy)))
        for sh in ([] if guide is not None else SHAPES.get(it['hint'], [])):
            k = sh[0]; a = [ev(v, it['w'], it['h']) for v in sh[1:]]
            if k == 'r': d.rectangle([x + a[0] * S, y + a[1] * S, x + a[2] * S, y + a[3] * S], outline=BL, width=2 * S)
            elif k == 'e': d.ellipse([x + (a[0] - a[2]) * S, y + (a[1] - a[3]) * S, x + (a[0] + a[2]) * S, y + (a[1] + a[3]) * S], outline=BL, width=2 * S)
            else: d.line([x + a[0] * S, y + a[1] * S, x + a[2] * S, y + a[3] * S], fill=BL, width=2 * S)
        if it['hint'] in FLOOR_HINTS:
            fd = FOOT_DEPTH.get(it['hint'], 128)
            fd = it['h'] if fd is None else fd
            fw = FOOT_WIDTH.get(it['hint'], it['w'])
            fx0, fy0, fx1, fy1 = x + (it['w'] - fw) * S // 2, y + it['h'] * S - fd * S, x + (it['w'] + fw) * S // 2, y + h
            seg = 10 * S
            for t in range(0, int(fx1 - fx0), 2 * seg):
                d.line([(fx0 + t, fy0), (min(fx0 + t + seg, fx1), fy0)], fill=GN, width=S)
                d.line([(fx0 + t, fy1 - 1), (min(fx0 + t + seg, fx1), fy1 - 1)], fill=GN, width=S)
            for t in range(0, int(fy1 - fy0), 2 * seg):
                d.line([(fx0, fy0 + t), (fx0, min(fy0 + t + seg, fy1))], fill=GN, width=S)
                d.line([(fx1 - 1, fy0 + t), (fx1 - 1, min(fy0 + t + seg, fy1))], fill=GN, width=S)
        fl = it['flags']
        if 'flush' in fl or 'flushl' in fl:
            None
        if it['hint'] == 'module':
            if fl in ('flush', 'flushr'): d.line([(x, y + 70 * S), (x, y + 186 * S)], fill=MG, width=3 * S)
            if fl in ('flush', 'flushl'): d.line([(x + w - 2 * S, y + 70 * S), (x + w - 2 * S, y + 186 * S)], fill=MG, width=3 * S)
        if it['hint'] in ('wallplain', 'walllow'):
            d.line([(x, y), (x, y + h)], fill=MG, width=3 * S); d.line([(x + w - 2 * S, y), (x + w - 2 * S, y + h)], fill=MG, width=3 * S)
    return im

GUIDES = os.path.join(os.path.dirname(__file__), 'guides')
def piece_guide(pid):
    """A better guide drawing for a piece (see grid_guides.py), if one was made; else None and the plain shapes are drawn."""
    path = os.path.join(GUIDES, pid + '.png')
    return Image.open(path).convert('RGBA') if os.path.exists(path) else None

def png_uri(im):
    b = io.BytesIO(); im.save(b, 'PNG', optimize=True); return 'data:image/png;base64,' + base64.b64encode(b.getvalue()).decode()

PROMPT = """ภาพแนบคือแม่แบบ "{title}" ของเกมร้านอาหารบนเกาะ Salvora (Stardew Valley-like, มุมมองบนเฉียง top-down 3/4) ช่วยวาดของทุกชิ้นลงในกรอบของมัน

สไตล์: ภาพวาดนุ่ม ๆ แบบ hand-painted สีอบอุ่น ขอบไม่คมแข็ง (ไม่ใช่พิกเซลอาร์ต) แสงมาจากด้านซ้ายบน ทุกชิ้นในแผ่นต้องโทนสีและฝีมือเดียวกัน

กติกา (สำคัญมาก):
1. ส่งภาพกลับเป็น PNG ขนาด {w}x{h} px เท่ากับแม่แบบทุกพิกเซล ห้ามย่อ ห้ามขยาย ห้ามตัดขอบ ห้ามเลื่อนกรอบ
2. วาดแต่ละชิ้นอยู่ในกรอบสีฟ้าของตัวเอง ห้ามล้ำออกนอกกรอบ พื้นหลังนอกตัวของต้องโปร่งใส (ยกเว้นพื้นกระเบื้อง/ดินที่ต้องเต็มกรอบ)
3. ห้ามวาดเส้นแม่แบบ ตัวหนังสือ หรือเส้นไกด์ลงในภาพ
4. ของที่ตั้งบนพื้น: ขอบล่างของภาพคือพื้นที่ที่ของยืน ตัวของต้องชิดขอบล่างและเต็มความกว้างของช่องที่กิน (เส้นประเขียวคือขอบเขตของช่อง) ห้ามวาดเงาตกพื้นเอง เกมวาดเงาให้
5. ของที่ต้องต่อกัน (พื้น ผนัง เคาน์เตอร์) ต้องชนขอบซ้ายขวาพอดี ลายต่อกันเนียนไม่มีรอยต่อ
6. ชื่อและคำอธิบายบนแม่แบบบอกว่าแต่ละกรอบคือของอะไร
7. แสง: วาดด้วยแสงกลางวันกลาง ๆ มาจากซ้ายบน สีอบอุ่นอิ่มพอสมควร (ไม่ซีดและไม่มืดเกินไป) เพราะเกมมีเวลาเช้า เย็น กลางคืน และจะคลุมสีทับทั้งฉากเอง ห้ามวาดแสงยามเย็นหรือกลางคืนลงในภาพ
"""

def build_sheet(n, sheet):
    items, heads, H = layout(sheet)
    g1 = draw_guide(items, heads, H, 1, sheet['title']); g2 = draw_guide(items, heads, H, 2, sheet['title'])
    blank = Image.new('RGBA', (SHEET_W, H), (0, 0, 0, 0))
    stem = f"set_template_{n}_{sheet['id']}"
    g1.convert('RGB').save(f'{OUT}/{stem}_guide.png'); g2.convert('RGB').save(f'{OUT}/{stem}_guide_2x.png'); blank.save(f'{OUT}/{stem}_blank.png')
    prompt = PROMPT.format(title=sheet['title'], w=SHEET_W, h=H)
    open(f'{OUT}/{stem}_prompt.txt', 'w', encoding='utf-8').write(prompt)
    lay = {'id': sheet['id'], 'title': sheet['title'], 'status': sheet['status'], 'note': sheet['note'], 'sheetW': SHEET_W, 'sheetH': H, 'categories': sheet['categories'], 'stem': stem}
    return lay, items, (g1, g2, blank), prompt

STATUS_TH = {'now': 'ใช้ในเกมตอนนี้', 'next': 'จะเพิ่มเข้าเกมต่อ', 'later': 'เกมยังไม่ใช้'}

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for old in glob.glob(f'{OUT}/*.zip') + glob.glob(f'{OUT}/set_template_*') + [f'{OUT}/preview.png']:
        if os.path.exists(old): os.remove(old)
    sheets, all_items, imgs = [], [], []
    for n, sh in enumerate(SHEETS, 1):
        lay, items, ims, prompt = build_sheet(n, sh)
        sheets.append(lay); all_items += items; imgs.append({'g1': png_uri(ims[0]), 'g2': png_uri(ims[1]), 'blank': png_uri(ims[2]), 'prompt': prompt})
    lay = {'sheets': sheets, 'items': all_items, 'categories': CATEGORIES}
    tpl = open('tools/workshop/template.html', encoding='utf-8').read()
    html = tpl.replace('__LAYOUT__', json.dumps(lay, ensure_ascii=False)).replace('__IMAGES__', json.dumps(imgs, ensure_ascii=False))
    open(f'{OUT}/index.html', 'w', encoding='utf-8').write(html)
    json.dump(lay, open(f'{OUT}/set_template_layout.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    note = {'tile': 'ทึบ ต่อกันทุกทิศ', 'flush': 'ปลายซ้ายขวาชนขอบภาพ', 'flushr': 'ปลายซ้ายชนขอบ', 'flushl': 'ปลายขวาชนขอบ', 'flat': 'ภาพแบนบนพื้น', '': ''}
    rows = [f'# ชุดเซ็ต (Set v2): {len(all_items)} ชิ้นใน {len(sheets)} แผ่น', '',
            'สร้างอัตโนมัติจาก `tools/workshop/items.py` ด้วย `python3 tools/workshop/build.py` อย่าแก้มือ เว็บ Art Workshop (`/art-workshop/`) ใช้รายการนี้ ชื่อไฟล์ตรงกับที่เกมโหลด (`assets/td/<โฟลเดอร์>/<ชื่อ>.png`)', '',
            '- **ใช้ในเกมตอนนี้**: เกมโหลดไฟล์ชื่อนี้ทันทีที่มี ขนาดตรงกับขนาดของในเกม (`Catalog`)', '- **จะเพิ่มเข้าเกมต่อ**: ชิ้นของชุดตกแต่งร้าน ยังไม่มีในร้านค้า ผมจะเพิ่มรายการสินค้าให้ตรงกับภาพที่ได้', '- **เกมยังไม่ใช้**: ไอคอนและตัวละคร ทำภาพไว้ล่วงหน้าตามชื่อและขนาดนี้', '']
    for sh, lay_s in zip(SHEETS, sheets):
        rows += [f"## {sh['title']} ({STATUS_TH[sh['status']]}, แม่แบบ {lay_s['sheetW']}x{lay_s['sheetH']} px)", '', '| หมวด | ชื่อ | โฟลเดอร์ | ไฟล์ | ขนาด (px) | หมายเหตุ |', '|---|---|---|---|---|---|']
        for it in all_items:
            if it['sheet'] == sh['id']:
                rows.append(f"| {it['category']} | {it['label']} | `{it['folder']}` | `{it['file']}.png` | {it['w']}x{it['h']} | {note.get(it['flags'], '')} |")
        rows.append('')
    rows += ['ของบนพื้น (เฟอร์นิเจอร์ ครัว ตกแต่ง ของเล็ก ฟาร์ม): ขอบล่างของภาพคือขอบล่างของช่องที่ของกิน ตัวของต้องเต็มช่อง (ท็อปเคาน์เตอร์ต่อถึงผนังด้านหลัง) ภาพสูงกว่าช่องได้เพื่อทำของสูง ของติดผนัง (หน้าต่าง ประตู โคมไฟ ภาพวาด ฮู้ด): เส้นฐานสูงจากขอบล่างของภาพ 24 px หน้าต่างติดสูงจากพื้นผนัง 70 px (ในเกม) ประตูอยู่บนพื้น เกมวาดเงาแนบพื้นใต้ของให้เอง']
    open('docs/ART_SET.md', 'w', encoding='utf-8').write('\n'.join(rows) + '\n')
    print('items', len(all_items), 'sheets', [(l['sheetW'], l['sheetH']) for l in sheets], 'html', len(html))
