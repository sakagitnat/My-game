#!/usr/bin/env python3
"""Turns a picture of many guide drawings (one image, pieces in a grid on a plain background) into one guide drawing per piece.
The pieces are matched to template ids in reading order (left to right, top to bottom).

  python3 tools/workshop/grid_guides.py --list "ต้นไม้ หิน พุ่ม"      prints the pieces of a category in order (ids, names, frame sizes)
  python3 tools/workshop/grid_guides.py IMAGE --cols 4 --rows 2 --ids obs_tree,obs_rock,obs_bush,...
  python3 tools/workshop/grid_guides.py IMAGE --cols 4 --rows 2 --category "ต้นไม้ หิน พุ่ม"   (same, ids taken from the category)

Writes tools/workshop/guides/<id>.png (trimmed, transparent background). `python3 tools/workshop/build.py` then draws
them inside the frames of the template instead of the plain boxes and circles."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
from items import ITEMS

OUT = os.path.join(os.path.dirname(__file__), 'guides')
arg = lambda name, default=None: sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default

if '--list' in sys.argv:
    cat = arg('--list')
    for it in [i for i in ITEMS if i[5] == cat]:
        print(f"{it[0]}\t{it[6]}\t{it[3]}x{it[4]}")
    sys.exit(0)

ids = arg('--ids', '').split(',') if '--ids' in sys.argv else [i[0] for i in ITEMS if i[5] == arg('--category')]
cols, rows = int(arg('--cols')), int(arg('--rows'))
tol = int(arg('--tol', 28))
img = Image.open(sys.argv[1]).convert('RGBA')
W, H = img.size
cw, ch = W // cols, H // rows
has_alpha = img.getchannel('A').getextrema()[0] < 250
bg = img.getpixel((2, 2))[:3]
os.makedirs(OUT, exist_ok=True)
made = []
for n, pid in enumerate(ids):
    r, c = divmod(n, cols)
    if r >= rows:
        print(f'more ids than cells: {pid} skipped'); continue
    cell = img.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
    px = cell.load()
    out = Image.new('RGBA', cell.size, (0, 0, 0, 0)); po = out.load()
    for y in range(cell.height):
        for x in range(cell.width):
            p = px[x, y]
            if has_alpha:
                a = p[3]
            else:
                d = abs(p[0] - bg[0]) + abs(p[1] - bg[1]) + abs(p[2] - bg[2])
                a = max(0, min(255, (d - tol) * 6))
            if a > 0:
                po[x, y] = (p[0], p[1], p[2], a)
    box = out.getchannel('A').point(lambda v: 255 if v > 40 else 0).getbbox()
    if box is None:
        print(f'{pid}: nothing found in cell {r + 1},{c + 1}'); continue
    out.crop(box).save(os.path.join(OUT, pid + '.png'))
    made.append(pid)
print(f'{len(made)} guide drawings written to tools/workshop/guides/: ' + ', '.join(made))
