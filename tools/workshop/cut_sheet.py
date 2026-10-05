#!/usr/bin/env python3
"""Cuts a drawn template sheet into the game's asset files (what the web workshop's ZIP does, for use in the repo) and checks it.
python3 tools/workshop/cut_sheet.py SHEET.png --sheet N [--skip id,id] [--report] [--dry]
  --sheet N   which sheet of the template the picture is (1..5, see docs/ART_SET.md)
              the sheet is pixel art at 32 px per cell: its size is pxW x pxH of that sheet (e.g. 480 x 727), or a whole multiple of it
              (each pixel drawn as m x m); pieces are written at their real pixel size
  --report    print a line for every piece: empty / ok / what is off (size, standing on the bottom edge, filling the cell, tile edges)
  --dry       check only, write nothing"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
lay = json.load(open('assets/td/art_workshop/set_template_layout.json'))
arg = lambda name, default=None: sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default
n_sheet = int(arg('--sheet', 1))
sh = lay['sheets'][n_sheet - 1]
sheet = Image.open(sys.argv[1]).convert('RGBA')
skip = set(arg('--skip', '').split(',')) - {''}
K = lay.get('k', 4)   # design size / pixel size
m = sheet.width / sh['pxW']   # how many sheet pixels make one art pixel
assert m >= 1 and m == int(m) and sheet.size == (sh['pxW'] * int(m), sh['pxH'] * int(m)), f"sheet size {sheet.size} does not match sheet {n_sheet} ({sh['pxW']}x{sh['pxH']} px, or a whole multiple of it)"
m = int(m)
from piece_check import check

done = bad = empty = 0
for it in lay['items']:
    if it['sheet'] != sh['id'] or it['id'] in skip:
        continue
    pw, ph = it['w'] // K, it['h'] // K
    c = sheet.crop((it['x'] // K * m, it['y'] // K * m, (it['x'] // K + pw) * m, (it['y'] // K + ph) * m))
    if m > 1:
        c = c.resize((pw, ph), Image.NEAREST)
    design = c.resize((it['w'], it['h']), Image.NEAREST)   # the checks are written for the design size (4x the pixels)
    res = check(it, design, c)
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
