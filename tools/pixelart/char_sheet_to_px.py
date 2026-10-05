#!/usr/bin/env python3
"""Turns a character sheet made by an image generator (3 columns x 4 rows: front, left, right, back; walk / stand / walk) into game frames:
32 x 64 px, one scale for every frame, feet on row 59, centred, stray bits removed (only the biggest blob is kept), hard transparency, a small colour set.
A generator's sheet is not real pixel art (thousands of colours, soft edges); this makes it usable to test in the game and to polish in a drawing app.
python3 tools/pixelart/char_sheet_to_px.py SHEET.png OUTDIR [--height 58] [--colors 24] [--cols 3] [--rows 4]
writes OUTDIR/frame_<row>_<col>.png (32x64) and OUTDIR/sheet_px.png (cols x rows frames in one image) and OUTDIR/preview_4x.png"""
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage

arg = lambda n, d: type(d)(sys.argv[sys.argv.index(n) + 1]) if n in sys.argv else d

def biggest_blob(mask):
    lab, n = ndimage.label(mask, structure=np.ones((3, 3)))
    if n <= 1: return mask
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    return lab == (1 + int(np.argmax(sizes)))

def main():
    src, out = sys.argv[1], sys.argv[2]
    H = arg('--height', 58); NC = arg('--colors', 24); cols = arg('--cols', 3); rows = arg('--rows', 4)
    os.makedirs(out, exist_ok=True)
    im = Image.open(src).convert('RGBA'); a = np.array(im)
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0); im = Image.fromarray(a, 'RGBA')
    cw, ch = im.width / cols, im.height / rows
    cells = {}
    for r in range(rows):
        for c in range(cols):
            cell = im.crop((int(c * cw), int(r * ch), int((c + 1) * cw), int((r + 1) * ch)))
            m = biggest_blob(np.array(cell)[..., 3] > 0)
            arr = np.array(cell); arr[..., 3] = np.where(m, 255, 0)
            cell = Image.fromarray(arr, 'RGBA'); cells[(r, c)] = cell.crop(cell.getbbox())
    # one scale for all frames: the tallest standing frame (the middle column) becomes H px
    tall = max(cells[(r, cols // 2)].height for r in range(rows))
    S = H / tall
    sheet = Image.new('RGBA', (32 * cols, 64 * rows), (0, 0, 0, 0))
    for (r, c), cell in cells.items():
        w = max(1, round(cell.width * S)); h = max(1, round(cell.height * S))
        sm = cell.resize((w, h), Image.BOX)
        al = np.array(sm)[..., 3] > 100
        q = np.array(sm.convert('RGB').quantize(NC, method=Image.MEDIANCUT).convert('RGB'))
        fr = Image.fromarray(np.dstack([q, np.where(al, 255, 0)]).astype('uint8'), 'RGBA')
        fx = Image.new('RGBA', (32, 64), (0, 0, 0, 0))
        fx.alpha_composite(fr, ((32 - fr.width) // 2, 60 - fr.height))              # feet on row 59
        fx.save(f'{out}/frame_{r}_{c}.png'); sheet.alpha_composite(fx, (c * 32, r * 64))
    sheet.save(f'{out}/sheet_px.png')
    bg = Image.new('RGBA', (sheet.width + 8, sheet.height + 8), (240, 226, 210, 255)); bg.alpha_composite(sheet, (4, 4))
    bg.resize((bg.width * 4, bg.height * 4), Image.NEAREST).convert('RGB').save(f'{out}/preview_4x.png')
    print(f'{len(cells)} frames, scale {S:.3f}, written to {out}')

if __name__ == '__main__':
    if len(sys.argv) < 3: print(__doc__); sys.exit(1)
    main()
