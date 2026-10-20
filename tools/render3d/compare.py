#!/usr/bin/env python3
"""Side by side: the hand-coded pilot pieces (tools/pixelart) and the 3D-rendered ones (render.py + pixelize.py), at the same pixel size.
python3 tools/render3d/compare.py [DIR]     DIR holds the pixelized renders (default assets/td/art_workshop/pilot/render3d); writes _compare.png,
_room_hand.png and _room_3d.png there (the room is room_mock.py's layout with the pieces swapped)."""
import sys, os
HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, '..', 'pixelart'))
from PIL import Image, ImageDraw
import shop_pilot, room_mock, char_base

def load(d, n): return Image.open(os.path.join(d, n + '.png')).convert('RGBA')
def flip(im): return im.transpose(Image.FLIP_LEFT_RIGHT)

def compare(d, k=5):
    hand_chairs = [room_mock.chair(True), room_mock.chair_side(), room_mock.chair(False)]
    look = char_base.LOOKS['waitress']
    rows = [
        ('hand', [shop_pilot.table(), shop_pilot.stove()] + hand_chairs + [char_base.render(look, v, 0) for v in ('down', 'left', 'up')]),
        ('3d', [load(d, n) for n in ('rest_table_small_01', 'rest_stove_01', 'chair_front', 'chair_side', 'chair_back', 'cook_down_0', 'cook_left_0', 'cook_up_0')]),
        ('3d turns', [load(d, n) for n in ('rest_stove_01', 'rest_stove_side_01', 'rest_stove_back_01')] + [load(d, 'cook_down_%d' % f) for f in range(4)]),
    ]
    gap, lab = 6, 40
    W = lab + max(sum(p.width + gap for p in ps) for _, ps in rows) + gap
    H = sum(max(p.height for p in ps) + gap for _, ps in rows) + gap
    im = Image.new('RGBA', (W, H), (236, 232, 224, 255))
    dr = ImageDraw.Draw(im)
    y = gap
    for label, ps in rows:
        h = max(p.height for p in ps)
        dr.text((4, y + h // 2 - 4), label, fill=(90, 70, 60, 255))
        x = lab
        for p in ps: im.alpha_composite(p, (x, y + h - p.height)); x += p.width + gap     # bottoms on one line, as on the floor
        dr.line((lab, y + h, W - gap, y + h), fill=(200, 190, 175, 255))
        y += h + gap
    return im.resize((W * k, H * k), Image.NEAREST)

def room_3d(d):
    """room_mock.build() with the table, stove and chairs swapped for the 3D renders (everything else is the hand-coded room)."""
    saved = (dict(room_mock.PIECES), room_mock.chair, room_mock.chair_side)
    room_mock.PIECES['rest_table_small_01'] = lambda: load(d, 'rest_table_small_01')
    room_mock.PIECES['rest_stove_01'] = lambda: load(d, 'rest_stove_01')
    room_mock.chair = lambda front: load(d, 'chair_front' if front else 'chair_back')
    room_mock.chair_side = lambda: load(d, 'chair_side')
    try:
        return room_mock.build()
    finally:
        room_mock.PIECES.clear(); room_mock.PIECES.update(saved[0]); room_mock.chair, room_mock.chair_side = saved[1], saved[2]

if __name__ == '__main__':
    d = sys.argv[1] if len(sys.argv) > 1 else 'assets/td/art_workshop/pilot/render3d'
    compare(d).convert('RGB').save(os.path.join(d, '_compare.png'))
    room_mock.build().convert('RGB').save(os.path.join(d, '_room_hand.png'))
    room_3d(d).convert('RGB').save(os.path.join(d, '_room_3d.png'))
    print('written to', d)
