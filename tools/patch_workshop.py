#!/usr/bin/env python3
"""Fixes the starter templates of assets/td/art_workshop to match docs/ART_TOPDOWN.md:
- kitchen modules (counter, sink, stove, oven) are 128x128 and run flush to the left/right edge (no side margins)
- small tableware / utensils are 64x64 (about a third of a cell) instead of a whole cell
Rebuilds index.html (TEMPLATES + ATLAS_URL), salvora_art_workshop.zip and salvora_templates.zip."""
import re, json, base64, io, zipfile, os
from PIL import Image, ImageDraw

D = 'assets/td/art_workshop'
CYAN = (45, 170, 192, 120); BLUE = (44, 106, 172, 210); PINK = (224, 88, 120, 150); GREEN = (50, 157, 114, 210)

def b64(data): return base64.b64encode(data).decode()
def png_bytes(im):
    b = io.BytesIO(); im.save(b, 'PNG'); return b.getvalue()
def rgba(c): return f'rgba({c[0]},{c[1]},{c[2]},{c[3] / 255:.3f})'

# shape lists: ('rect', x0, y0, x1, y1) ('ell', cx, cy, rx, ry) ('line', x0, y0, x1, y1)
def module(kind):
    sh = [('rect', 0, 30, 127, 58), ('rect', 0, 58, 127, 104)]
    if kind == 'counter': sh += [('rect', 16, 68, 111, 96), ('line', 54, 76, 74, 76)]
    if kind == 'sink': sh += [('ell', 64, 44, 34, 9), ('line', 64, 30, 64, 38), ('rect', 16, 68, 111, 96)]
    if kind == 'stove': sh += [('ell', 36, 38, 11, 5), ('ell', 92, 38, 11, 5), ('ell', 36, 50, 11, 5), ('ell', 92, 50, 11, 5), ('rect', 16, 68, 111, 96), ('line', 30, 64, 98, 64)]
    if kind == 'oven': sh += [('rect', 14, 66, 113, 98), ('rect', 24, 72, 103, 92), ('line', 30, 63, 98, 63)]
    return 128, 128, sh
def prop(kind):
    sh = {'pan': [('ell', 28, 28, 15, 10), ('rect', 42, 26, 58, 30)],
          'pot': [('ell', 32, 30, 16, 11), ('line', 14, 28, 18, 28), ('line', 46, 28, 50, 28)],
          'plate': [('ell', 32, 32, 21, 12), ('ell', 32, 32, 14, 7)],
          'bowl': [('ell', 32, 30, 18, 12), ('ell', 32, 26, 14, 5)],
          'cup': [('ell', 30, 30, 9, 9), ('rect', 38, 26, 46, 34)],
          'knife': [('line', 12, 40, 52, 22), ('line', 12, 40, 12, 46)],
          'cutting_board': [('rect', 12, 22, 52, 40), ('ell', 46, 31, 2, 2)],
          'spatula': [('rect', 8, 30, 36, 36), ('rect', 36, 26, 52, 40)],
          'ladle': [('line', 10, 22, 40, 36), ('ell', 46, 38, 7, 6)]}[kind]
    return 64, 64, sh

def draw_guide(w, h, anchor, shapes, cols, rows):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w - 1, h - 1], outline=CYAN, width=2)
    for i in range(1, cols): d.line([(i * w // cols, 0), (i * w // cols, h - 1)], fill=CYAN, width=1)
    for j in range(1, rows): d.line([(0, j * h // rows), (w - 1, j * h // rows)], fill=CYAN, width=1)
    ay = anchor[1]; d.line([(0, ay), (w - 1, ay)], fill=PINK, width=1)
    d.line([(anchor[0] - 5, ay), (anchor[0] + 5, ay)], fill=GREEN, width=2); d.line([(anchor[0], ay - 5), (anchor[0], ay + 5)], fill=GREEN, width=2)
    for s in shapes:
        if s[0] == 'rect': d.rectangle(s[1:], outline=BLUE, width=2)
        elif s[0] == 'ell': d.ellipse([s[1] - s[3], s[2] - s[4], s[1] + s[3], s[2] + s[4]], outline=BLUE, width=2)
        else: d.line(s[1:], fill=BLUE, width=2)
    return im
def draw_svg(w, h, anchor, shapes, cols, rows, title):
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><title>{title} • 128 px grid</title><g id="guides">']
    o.append(f'<rect x="0" y="0" width="{w - 1}" height="{h - 1}" fill="none" stroke="{rgba(CYAN)}" stroke-width="2"/>')
    for i in range(1, cols): o.append(f'<polyline points="{i * w // cols},0 {i * w // cols},{h - 1}" fill="none" stroke="{rgba(CYAN)}" stroke-width="1"/>')
    for j in range(1, rows): o.append(f'<polyline points="0,{j * h // rows} {w - 1},{j * h // rows}" fill="none" stroke="{rgba(CYAN)}" stroke-width="1"/>')
    o.append(f'<polyline points="0,{anchor[1]} {w - 1},{anchor[1]}" fill="none" stroke="{rgba(PINK)}" stroke-width="1"/>')
    o.append(f'<polyline points="{anchor[0] - 5},{anchor[1]} {anchor[0] + 5},{anchor[1]}" fill="none" stroke="{rgba(GREEN)}" stroke-width="2"/>')
    o.append(f'<polyline points="{anchor[0]},{anchor[1] - 5} {anchor[0]},{anchor[1] + 5}" fill="none" stroke="{rgba(GREEN)}" stroke-width="2"/></g><g id="drawing">')
    for s in shapes:
        st = f'fill="none" stroke="{rgba(BLUE)}" stroke-width="2"'
        if s[0] == 'rect': o.append(f'<rect x="{s[1]}" y="{s[2]}" width="{s[3] - s[1]}" height="{s[4] - s[2]}" {st}/>')
        elif s[0] == 'ell': o.append(f'<ellipse cx="{s[1]}" cy="{s[2]}" rx="{s[3]}" ry="{s[4]}" {st}/>')
        else: o.append(f'<polyline points="{s[1]},{s[2]} {s[3]},{s[4]}" {st}/>')
    o.append('</g></svg>')
    return ''.join(o)

html = open(f'{D}/index.html', encoding='utf-8').read()
m = re.search(r'const TEMPLATES=(\[.*?\]);\s*const ATLAS_URL="(data:image/png;base64,[^"]+)"', html, re.S)
arr = json.loads(m.group(1))
atlas = Image.open(io.BytesIO(base64.b64decode(m.group(2).split(',', 1)[1]))).convert('RGBA')
new_files = {}
for t in arr:
    i = t['id']
    if i in ('counter', 'sink', 'stove', 'oven'):
        w, h, sh = module(i)
        t['label'] = {'counter': 'เคาน์เตอร์ (โมดูล 1 ช่อง ชนขอบซ้ายขวา)', 'sink': 'อ่างล้างจาน (โมดูล 1 ช่อง)', 'stove': 'เตา (โมดูล 1 ช่อง)', 'oven': 'เตาอบใต้เคาน์เตอร์ (โมดูล 1 ช่อง)'}[i]
    elif i in ('pan', 'pot', 'plate', 'bowl', 'cup', 'knife', 'cutting_board', 'spatula', 'ladle'):
        w, h, sh = prop(i)
        t['label'] = t['label'].split(' (')[0] + ' (เล็ก 64 px)'
    else:
        continue
    ox, oy, ow, oh = t['x'], t['y'], t['w'], t['h']
    atlas.paste((0, 0, 0, 0), [ox, oy, ox + ow, oy + oh])
    t['w'], t['h'] = w, h
    t['cols'] = max(1, w // 128); t['rows'] = max(1, h // 128)
    t['anchor'] = [w // 2, 104 if w == 128 else 52]
    g = draw_guide(w, h, t['anchor'], sh, t['cols'], t['rows'])
    atlas.alpha_composite(g, (ox, oy))
    blank = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    svg = draw_svg(w, h, t['anchor'], sh, t['cols'], t['rows'], t['label'])
    t['guide'] = 'data:image/png;base64,' + b64(png_bytes(g)); t['blank'] = 'data:image/png;base64,' + b64(png_bytes(blank))
    t['svg'] = 'data:image/svg+xml;base64,' + b64(svg.encode('utf-8'))
    new_files[i] = (g, blank, svg)

# Wall pieces and wall decor that the first version of the workshop did not have.
NEW = [
    ('wall_plain', 'ผนังเรียบ (1 ช่อง กว้าง สูง 2 ช่อง ซ้ายขวาต่อเนียน)', 128, 256, [('rect', 0, 0, 127, 24), ('rect', 0, 24, 127, 200), ('rect', 0, 200, 127, 255)], 232),
    ('wall_low', 'ผนังเตี้ย / ราว', 128, 64, [('rect', 0, 8, 127, 56)], 56),
    ('wall_side', 'ผนังข้าง (แถบบางตั้ง 32x256)', 32, 256, [('rect', 3, 3, 28, 252)], 232),
    ('wall_lamp', 'โคมไฟติดผนัง', 128, 128, [('rect', 48, 40, 80, 100), ('line', 64, 28, 64, 40)], 104),
    ('wall_painting', 'ภาพวาดติดผนัง', 128, 128, [('rect', 20, 36, 108, 100), ('rect', 28, 44, 100, 92)], 104),
    ('rug', 'พรมปูพื้น 2x2 (ภาพแบนบนพื้น)', 256, 256, [('rect', 20, 90, 235, 235), ('rect', 32, 102, 223, 223)], 232),
]
def free_slot(w, h):
    for y in range(0, 2560 - h + 1, 32):
        for x in range(0, 1024 - w + 1, 32):
            ok = True
            for t in arr:
                if x < t['x'] + t['w'] + 8 and x + w + 8 > t['x'] and y < t['y'] + t['h'] + 8 and y + h + 8 > t['y']:
                    ok = False; break
            if ok: return x, y
    raise SystemExit('no room in the atlas for ' + str(w) + 'x' + str(h))
for (i, label, w, h, sh, ay) in NEW:
    if any(t['id'] == i for t in arr):
        continue
    x, y = free_slot(w, h)
    t = {'id': i, 'label': label, 'category': 'อาคาร' if i.startswith('wall') else 'เฟอร์นิเจอร์', 'w': w, 'h': h, 'cols': max(1, w // 128), 'rows': max(1, h // 128), 'anchor': [w // 2, ay], 'x': x, 'y': y}
    g = draw_guide(w, h, t['anchor'], sh, t['cols'], t['rows'])
    blank = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    svg = draw_svg(w, h, t['anchor'], sh, t['cols'], t['rows'], label)
    t['guide'] = 'data:image/png;base64,' + b64(png_bytes(g)); t['blank'] = 'data:image/png;base64,' + b64(png_bytes(blank)); t['svg'] = 'data:image/svg+xml;base64,' + b64(svg.encode('utf-8'))
    atlas.alpha_composite(g, (x, y))
    arr.append(t); new_files[i] = (g, blank, svg)

html = html.replace(m.group(0), 'const TEMPLATES=' + json.dumps(arr, ensure_ascii=False) + ';\nconst ATLAS_URL="data:image/png;base64,' + b64(png_bytes(atlas)) + '"', 1)
html = re.sub(r'(?<![\d,+/])37(\s*(?:แบบ|ชิ้น))', lambda mm: str(len(arr)) + mm.group(1), html)
html = re.sub(r'แม่แบบ <span>\d+</span>', 'แม่แบบ <span>%d</span>' % len(arr), html)
open(f'{D}/index.html', 'w', encoding='utf-8').write(html)

# zips
tz_path = f'{D}/salvora_templates.zip'
old = zipfile.ZipFile(tz_path)
items = {n: old.read(n) for n in old.namelist()}
old.close()
for i, (g, blank, svg) in new_files.items():
    items[f'templates/{i}_guide.png'] = png_bytes(g); items[f'templates/{i}_blank.png'] = png_bytes(blank); items[f'templates/{i}_guide.svg'] = svg.encode('utf-8')
items['atlas_guide.png'] = png_bytes(atlas)
lay = json.loads(items['templates.json'])
have = {e['id'] for e in lay}
for t in arr:
    if t['id'] not in have:
        lay.append({k: t[k] for k in ('id', 'label', 'category', 'w', 'h', 'cols', 'rows', 'anchor', 'x', 'y')} | {'guide': 'templates/%s_guide.png' % t['id'], 'blank': 'templates/%s_blank.png' % t['id'], 'svg': 'templates/%s_guide.svg' % t['id']})
for e in lay:
    t = next(x for x in arr if x['id'] == e['id'])
    for k in ('label', 'w', 'h', 'cols', 'rows', 'anchor'): e[k] = t[k]
items['templates.json'] = json.dumps(lay, ensure_ascii=False).encode('utf-8')
with zipfile.ZipFile(tz_path, 'w', zipfile.ZIP_DEFLATED) as z:
    for n, b in items.items(): z.writestr(n, b)
wz = f'{D}/salvora_art_workshop.zip'
old = zipfile.ZipFile(wz); wi = {n: old.read(n) for n in old.namelist()}; old.close()
wi['Salvora-Art-Workshop.html'] = html.encode('utf-8')
with zipfile.ZipFile(wz, 'w', zipfile.ZIP_DEFLATED) as z:
    for n, b in wi.items(): z.writestr(n, b)
print('patched', sorted(new_files))
