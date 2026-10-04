#!/usr/bin/env python3
"""Cuts a drawn template sheet into the game's asset files (what the web workshop's ZIP does, for use in the repo) and checks it.
python3 tools/workshop/cut_sheet.py SHEET.png --sheet N [--skip id,id] [--report] [--dry]
  --sheet N   which sheet of the template the picture is (1..5, see docs/ART_SET.md)
  --report    print a line for every piece: empty / ok / what is off (size, standing on the bottom edge, filling the cell, tile edges)
  --dry       check only, write nothing"""
import sys, os, json
from PIL import Image
lay = json.load(open('assets/td/art_workshop/set_template_layout.json'))
arg = lambda name, default=None: sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default
n_sheet = int(arg('--sheet', 1))
sh = lay['sheets'][n_sheet - 1]
sheet = Image.open(sys.argv[1]).convert('RGBA')
skip = set(arg('--skip', '').split(',')) - {''}
k = sheet.width // sh['sheetW']
assert k >= 1 and sheet.size == (sh['sheetW'] * k, sh['sheetH'] * k), f"sheet size {sheet.size} does not match sheet {n_sheet} ({sh['sheetW']}x{sh['sheetH']} or a multiple)"
FLOOR = ('module', 'fridge', 'table', 'chair', 'stool', 'register', 'shelf', 'sign', 'plant', 'floorlamp', 'bin', 'crate', 'table2', 'stove2', 'tree', 'rock', 'bush', 'fence', 'coop', 'vase', 'prop')

def check(it, c):
    """Problems of one cut piece, judged on the pixels (c is already at the piece's own size)."""
    a = c.getchannel('A'); bbox = a.point(lambda v: 255 if v > 24 else 0).getbbox()
    if bbox is None:
        return None
    w, h = c.size; x0, y0, x1, y1 = bbox; out = []
    opaque = sum(1 for v in a.tobytes() if v > 250) / (w * h)
    if it['flags'] in ('tile', 'flat') :
        if opaque < 0.99: out.append(f'ground must fill the whole frame ({opaque*100:.0f}% filled)')
    elif it['hint'].startswith(('edge_', 'corner_')):
        if opaque > 0.9: out.append('an edge piece must be mostly transparent: only the neighbouring ground near that side')
    else:
        if x0 <= 1 or y0 <= 1 or x1 >= w - 1: out.append('the picture touches or crosses the frame (it may be cut off)')
        if it['hint'] in FLOOR and y1 < h - 8: out.append(f'does not stand on the bottom edge: it ends {h - y1} px above it (things on the floor sit on the bottom edge)')
        if it['hint'] in ('table', 'table2', 'stove2', 'module', 'coop', 'fence') and x1 - x0 < w * 0.8: out.append(f'too narrow for the cells it takes: {x1 - x0} of {w} px wide (it should fill them)')
        if it['hint'] in ('char',) and (y1 - y0) < h * 0.6: out.append('character looks too small in its frame')
    return out

done = bad = empty = 0
for it in lay['items']:
    if it['sheet'] != sh['id'] or it['id'] in skip:
        continue
    c = sheet.crop((it['x'] * k, it['y'] * k, (it['x'] + it['w']) * k, (it['y'] + it['h']) * k))
    if k > 1:
        c = c.resize((it['w'], it['h']), Image.LANCZOS)
    res = check(it, c)
    if res is None:
        empty += 1
        if '--report' in sys.argv: print(f"empty   {it['folder']}/{it['file']}.png")
        continue
    if res:
        bad += 1
    if '--report' in sys.argv:
        print(('check   ' if res else 'ok      ') + f"{it['folder']}/{it['file']}.png" + ('  - ' + '; '.join(res) if res else ''))
    if '--dry' not in sys.argv:
        d = f"assets/td/{it['folder']}"
        os.makedirs(d, exist_ok=True)
        c.save(f"{d}/{it['file']}.png")
    done += 1
print(f"sheet {n_sheet} ({sh['title']}): {done} pieces found, {bad} to check, {empty} empty" + ('' if '--dry' in sys.argv else ', written to assets/td/'))
