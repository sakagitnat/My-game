#!/usr/bin/env python3
"""Cuts a drawn template sheet into the game's asset files (what the web workshop's ZIP does, for use in the repo).
python3 tools/workshop/cut_sheet.py SHEET.png [--skip id,id]  -> assets/td/<folder>/<file>.png"""
import sys, os, json
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
lay = json.load(open('assets/td/art_workshop/set_template_layout.json'))
sheet = Image.open(sys.argv[1]).convert('RGBA')
skip = set()
if '--skip' in sys.argv:
    skip = set(sys.argv[sys.argv.index('--skip') + 1].split(','))
k = sheet.width // lay['sheetW']
assert sheet.size == (lay['sheetW'] * k, lay['sheetH'] * k), 'sheet size does not match the template'
n = 0
for it in lay['items']:
    if it['id'] in skip:
        continue
    c = sheet.crop((it['x'] * k, it['y'] * k, (it['x'] + it['w']) * k, (it['y'] + it['h']) * k))
    if k > 1:
        c = c.resize((it['w'], it['h']), Image.LANCZOS)
    if c.getchannel('A').getbbox() is None:
        continue
    d = f"assets/td/{it['folder']}"
    os.makedirs(d, exist_ok=True)
    c.save(f"{d}/{it['file']}.png")
    n += 1
print('cut', n, 'pieces')
