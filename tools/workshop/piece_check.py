"""Checks of one cut piece (shared by cut_sheet.py and its tests). `it` is a layout item (flags, hint), `c` the RGBA piece at its own size."""
# standing on the floor: the bottom edge of the picture is the floor
FLOOR = ('module', 'fridge', 'table', 'tablelong', 'chair', 'stool', 'register', 'shelf', 'sign', 'plant', 'floorlamp', 'bin', 'crate', 'table2', 'stove2',
         'tree', 'treesmall', 'rock', 'bush', 'fence', 'coop', 'vase', 'prop', 'crop1', 'crop2', 'crop3', 'crop4')
# pieces whose body fills the whole width of the frame (they join their neighbours or fill the cells they take)
FILL_WIDTH = ('module', 'table', 'table2', 'stove2', 'tablelong', 'coop', 'fence', 'wallplain', 'walllow', 'wallside', 'rug')
# pieces that fill the whole height too (a wall), so they may touch the top
FILL_HEIGHT = ('wallplain', 'walllow', 'wallside')

def check(it, c):
    """Problems of one piece, judged on the pixels. None when the frame is empty."""
    a = c.getchannel('A'); bbox = a.point(lambda v: 255 if v > 24 else 0).getbbox()
    if bbox is None:
        return None
    w, h = c.size; x0, y0, x1, y1 = bbox; out = []
    hint = it['hint']
    opaque = sum(1 for v in a.tobytes() if v > 250) / (w * h)
    if it['flags'] in ('tile', 'flat'):
        if opaque < 0.99: out.append(f'ground must fill the whole frame ({opaque*100:.0f}% filled)')
    elif hint.startswith(('edge_', 'corner_')):
        if opaque > 0.9: out.append('an edge piece must be mostly transparent: only the neighbouring ground near that side')
    else:
        # touching the left, right or top edge may mean the picture is cut off, unless the piece is meant to fill the frame that way
        if (x0 <= 1 and hint not in FILL_WIDTH) or (x1 >= w - 1 and hint not in FILL_WIDTH):
            out.append('the picture touches the left or right edge of the frame (it may be cut off)')
        # (things standing on the floor reach the top edge legitimately: the frame is exactly their height plus the depth of their top)
        if y0 <= 1 and hint not in FILL_HEIGHT and hint not in FLOOR:
            out.append('the picture touches the top edge of the frame (it may be cut off)')
        if hint in FLOOR and y1 < h - 8: out.append(f'does not stand on the bottom edge: it ends {h - y1} px above it (things on the floor sit on the bottom edge)')
        if hint in ('table', 'table2', 'stove2', 'module', 'coop', 'fence', 'tablelong') and x1 - x0 < w * 0.8: out.append(f'too narrow for the cells it takes: {x1 - x0} of {w} px wide (it should fill them)')
        if hint == 'char' and (y1 - y0) < h * 0.6: out.append('character looks too small in its frame')
    return out
