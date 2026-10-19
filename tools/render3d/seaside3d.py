#!/usr/bin/env python3
"""The seaside set as smooth rendered art: every upright picture the game loads (docs/ART_SET.md sheets 1 and 2) built as a soft 3D model
and rendered from the game's camera at 128 px per cell (shown at 64). Flat pictures (tilled soil) are rendered straight down.
Ground tiles are painted by ground_tiles.py. Same world for every piece: 1 Blender unit = 1 cell, heights in blocks.
.bpyenv/bin/python tools/render3d/seaside3d.py [OUTDIR] [names...]     (default OUTDIR assets/td; see render.py for the venv)"""
import sys, os, math, random
import bpy
from mathutils import Vector
sys.path.insert(0, os.path.dirname(__file__))
import render as R
from render import Model, TILT, ZS
from PIL import Image

PX = 128        # pixels per cell in the files
SS = 2          # render this many times bigger, then shrink: clean edges

# colours (sRGB): one place for the whole set
C = {
    'wall': '#f4e9d6', 'wall_dk': '#e3d3bb', 'trim': '#fbf7ef', 'blue': '#3d7fb8', 'blue_dk': '#2c5f8f', 'blue_lt': '#6ea9d8',
    'wood': '#c98a55', 'wood_lt': '#dba06a', 'wood_dk': '#8b5a36', 'trunk': '#8a5a3a', 'brass': '#e4b464', 'steel': '#3a4049',
    'steel_lt': '#5d6773', 'glass': '#b7e0ee', 'leaf_dk': '#3f7d3a', 'leaf': '#5d9e45', 'leaf_lt': '#86c25a', 'rock': '#a59c90',
    'rock_dk': '#7f776d', 'soil': '#8a5a38', 'soil_dk': '#6b442a', 'soil_wet': '#5a3a26', 'soil_wet_dk': '#43291b', 'red': '#d9483b',
    'red_dk': '#a8322a', 'gold': '#e8c35a', 'gold_dk': '#c99a35', 'stem': '#6a9a3e', 'cabbage': '#9fd27a', 'cabbage_lt': '#c8e8a0',
    'roof': '#3c79b2', 'roof_lt': '#5592c8', 'stone': '#b9ad99', 'berry': '#c8343a', 'cream': '#efe4d2', 'sea': '#4fa8c8',
    'sand': '#ead3a1', 'sky': '#8ec5e6',
}
def c(k): return C.get(k, k)

class M(Model):
    """Model with colour names, extra shapes, and soft organic clumps for leaves and rocks."""
    def box(self, *a, key='wall', bevel=0.0): return Model.box(self, *a, c(key), bevel)
    def cyl(self, x, y, z0, z1, r, key, verts=24): return Model.cyl(self, x, y, z0, z1, r, c(key), verts)
    def disc_front(self, x, y, z, r, depth, key, verts=24): return Model.disc_front(self, x, y, z, r, depth, c(key), verts)
    def ball(self, x, y, z, r, key, sx=1, sy=1, sz=1): return Model.ball(self, x, y, z, r, c(key), sx, sy, sz)
    def limb(self, a, b, r, key): return Model.limb(self, a, b, r, c(key))
    def gable(self, *a, key='roof'): return Model.gable(self, *a, c(key))
    def clump(self, x, y, z, r, key, seed=0, rough=0.22, sz=1.0, flat=False):
        """A soft lumpy ball: an icosphere pushed in and out by noise (leaves, bushes, rocks)."""
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4 if not flat else 2, radius=r, location=(x, y, z * ZS))
        ob = bpy.context.object
        ob.scale = (1, 1, sz * ZS)
        tex = bpy.data.textures.new('n%d' % seed, 'CLOUDS'); tex.noise_scale = 0.35 * r + 0.05; tex.noise_depth = 2
        md = ob.modifiers.new('d', 'DISPLACE'); md.texture = tex; md.strength = rough * r; md.mid_level = 0.5
        md.texture_coords = 'OBJECT'
        if flat: bpy.ops.object.shade_flat()
        else: bpy.ops.object.shade_smooth()
        return self._own(ob, c(key))
    def lathe(self, x, y, z0, profile, key, segs=32):
        """A turned shape (vase, pot): profile is [(radius, height)] from the bottom up."""
        verts, faces = [], []
        n = len(profile)
        for i in range(segs):
            a = 2 * math.pi * i / segs
            for r, h in profile: verts.append((x + r * math.cos(a), y + r * math.sin(a), (z0 + h) * ZS))
        for i in range(segs):
            j = (i + 1) % segs
            for k in range(n - 1): faces.append((i * n + k, j * n + k, j * n + k + 1, i * n + k + 1))
        verts.append((x, y, z0 * ZS)); faces += [(len(verts) - 1, j * n, i * n) for i in range(segs) for j in [(i + 1) % segs]]
        me = bpy.data.meshes.new('lathe'); me.from_pydata(verts, [], faces); me.update()
        for p in me.polygons: p.use_smooth = True
        ob = bpy.data.objects.new('lathe', me); bpy.context.collection.objects.link(ob)
        return self._own(ob, c(key))

# ======================================================================== shop
def table(m):
    """1.5 x 1 cells, waist-low: a two-plank top with rounded edges, an apron, four turned legs."""
    w, d, top = 1.5, 1.0, 0.62
    m.box(0, 0, top - 0.1, w, d / 2 - 0.008, top, key='wood_lt', bevel=0.025)
    m.box(0, d / 2 + 0.008, top - 0.1, w, d, top, key='wood', bevel=0.025)
    m.box(0.06, 0.06, top - 0.2, w - 0.06, d - 0.06, top - 0.1, key='wood_dk', bevel=0.01)
    for x in (0.12, w - 0.12):
        for y in (0.12, d - 0.12): m.cyl(x, y, 0, top - 0.1, 0.07, 'wood_dk')
    return w, d

def stove(m):
    """1.5 x 1 cells, about a block tall: cream enamel body, black hob with two burners, blue oven door, brass rail and knobs."""
    w, d, h = 1.5, 1.0, 0.72
    m.box(0, 0, 0.04, w, d, h, key='cream', bevel=0.03)
    m.box(0.02, 0.02, 0, w - 0.02, d - 0.02, 0.06, key='steel')
    m.box(0.05, 0.12, h, w - 0.05, d - 0.1, h + 0.012, key='steel')
    for x in (0.42, w - 0.42):
        m.cyl(x, 0.5, h, h + 0.035, 0.17, 'steel_lt'); m.cyl(x, 0.5, h + 0.03, h + 0.05, 0.1, 'steel')
    m.box(0, d - 0.1, h, w, d, h + 0.2, key='trim', bevel=0.015)                                 # tiled back splash
    for x in [0.25 * i for i in range(1, 6)]: m.box(x - 0.006, d - 0.105, h + 0.01, x + 0.006, d - 0.1, h + 0.19, key='blue_lt')
    m.box(0.12, -0.025, 0.1, w - 0.12, 0.0, 0.53, key='blue', bevel=0.01)                       # oven door
    m.box(0.25, -0.035, 0.18, w - 0.25, -0.02, 0.42, key='steel', bevel=0.01)                   # window
    m.limb((0.22, -0.07, 0.47), (w - 0.22, -0.07, 0.47), 0.018, 'brass')                        # rail
    for x in (0.22, w - 0.22): m.limb((x, -0.07, 0.47), (x, -0.005, 0.47), 0.014, 'brass')
    for x in (0.28, 0.48, w - 0.48, w - 0.28): m.disc_front(x, -0.01, 0.63, 0.04, 0.03, 'brass')
    return w, d

def vase_small(m):
    m.lathe(0.25, 0.25, 0, [(0.07, 0), (0.1, 0.04), (0.11, 0.1), (0.08, 0.17), (0.05, 0.22), (0.06, 0.25), (0.055, 0.25)], 'trim')
    m.lathe(0.25, 0.25, 0.08, [(0.112, 0), (0.112, 0.025)], 'blue')
    for i, k in enumerate(('red', 'gold', 'red')):
        a = i * 2.1
        m.limb((0.25, 0.25, 0.22), (0.25 + 0.05 * math.cos(a), 0.25 + 0.03 * math.sin(a), 0.33), 0.008, 'stem')
        m.ball(0.25 + 0.05 * math.cos(a), 0.25 + 0.03 * math.sin(a), 0.34, 0.03, k)
    return 0.5, 0.5

def vase_large(m):
    m.lathe(0.5, 0.5, 0, [(0.13, 0), (0.2, 0.08), (0.24, 0.2), (0.2, 0.34), (0.11, 0.44), (0.09, 0.5), (0.12, 0.55), (0.1, 0.55)], 'trim')
    for z in (0.16, 0.26): m.lathe(0.5, 0.5, z, [(0.245, 0), (0.245, 0.03)], 'blue')
    rnd = random.Random(4)
    for i in range(6):
        a = i * 1.05
        tip = (0.5 + 0.12 * math.cos(a), 0.5 + 0.06 * math.sin(a), 0.72 + rnd.random() * 0.1)
        m.limb((0.5, 0.5, 0.5), tip, 0.012, 'stem')
        m.ball(tip[0], tip[1], tip[2] + 0.02, 0.05, ('red', 'gold', 'trim')[i % 3])
    for i in range(4): m.clump(0.5 + 0.1 * math.cos(i * 1.6), 0.5, 0.6, 0.06, 'leaf', seed=i)
    return 1.0, 1.0

def wall(m, low=False):
    """One cell of the shop's back wall: cream plaster, a blue board wainscot with a white rail, a white crown at the top."""
    w, h = 1.0, (3.0 if not low else 0.45)
    t = 0.12
    if low:
        m.box(0, 0, 0, w, t, h, key='blue', bevel=0.01); m.box(-0.001, -0.01, h - 0.06, w + 0.001, t + 0.01, h, key='trim', bevel=0.01)
        return w, t
    m.box(0, 0, 0, w, t, h, key='wall')
    m.box(0, -0.02, 0, w, 0.0, 1.0, key='blue')                                                   # wainscot boards
    for x in (0.25, 0.5, 0.75): m.box(x - 0.008, -0.025, 0.06, x + 0.008, -0.02, 0.95, key='blue_dk')
    m.box(0, -0.04, 0.95, w, 0.0, 1.03, key='trim', bevel=0.01)                                   # rail
    m.box(0, -0.035, 0, w, 0.0, 0.06, key='trim')                                                 # skirting
    m.box(0, -0.04, h - 0.1, w, t, h, key='trim', bevel=0.01)                                     # crown
    return w, t

def wall_side(m):
    """The wall seen end-on: a thick cream post with a blue foot."""
    w = 0.375
    m.box(0, 0, 0, w, 0.12, 3.0, key='wall_dk')
    m.box(-0.002, -0.02, 0, w + 0.002, 0.0, 1.0, key='blue')
    m.box(-0.002, -0.04, 2.9, w + 0.002, 0.12, 3.0, key='trim')
    return w, 0.12

def door(m, open_=False):
    """Two blocks tall in a white frame; blue boards with a brass porthole and handle. Open: swung inward, the room behind."""
    w = 1.0
    m.box(0.02, 0, 0, 0.12, 0.06, 2.1, key='trim', bevel=0.01); m.box(0.88, 0, 0, 0.98, 0.06, 2.1, key='trim', bevel=0.01)
    m.box(0.02, 0, 2.0, 0.98, 0.06, 2.12, key='trim', bevel=0.01)
    if open_:
        m.box(0.12, 0.06, 0, 0.88, 0.08, 2.0, key='wood_dk')                                    # the dark room behind
        m.box(0.12, 0.08, 0, 0.2, 0.75, 2.0, key='blue', bevel=0.01)
        return w, 0.08
    m.box(0.12, 0.02, 0, 0.88, 0.06, 2.0, key='blue', bevel=0.012)
    for x in (0.31, 0.5, 0.69): m.box(x - 0.006, 0.012, 0.05, x + 0.006, 0.02, 1.95, key='blue_dk')
    m.disc_front(0.5, 0.01, 1.55, 0.15, 0.03, 'brass'); m.disc_front(0.5, 0.0, 1.55, 0.11, 0.03, 'glass')
    m.ball(0.78, -0.02, 1.0, 0.035, 'brass')
    return w, 0.06

def window(m):
    """A white framed window with four panes and a flower box under it."""
    m.box(0.08, 0, 0.12, 0.92, 0.05, 0.98, key='trim', bevel=0.01)
    m.box(0.15, -0.005, 0.2, 0.85, 0.03, 0.92, key='glass')
    m.box(0.49, -0.02, 0.2, 0.51, 0.0, 0.92, key='trim'); m.box(0.15, -0.02, 0.55, 0.85, 0.0, 0.57, key='trim')
    m.box(0.05, -0.12, 0.04, 0.95, 0.03, 0.16, key='wood', bevel=0.01)                         # flower box
    for i in range(7):
        x = 0.12 + i * 0.12
        m.clump(x, -0.05, 0.2, 0.065, 'leaf', seed=i)
        m.ball(x + 0.02, -0.1, 0.24, 0.035, ('red', 'gold', 'trim')[i % 3])
    return 1.0, 0.05

def painting(m):
    m.box(0.12, 0, 0.18, 0.88, 0.04, 0.82, key='wood', bevel=0.012)
    m.box(0.18, -0.005, 0.24, 0.82, 0.02, 0.5, key='sea'); m.box(0.18, -0.005, 0.5, 0.82, 0.02, 0.76, key='sky')
    m.ball(0.66, -0.01, 0.63, 0.06, 'gold', 1, 0.2, 1)
    m.box(0.36, -0.012, 0.42, 0.4, 0.0, 0.62, key='trim'); m.box(0.3, -0.012, 0.38, 0.5, 0.0, 0.44, key='red')
    return 1.0, 0.04

# ======================================================================== outdoors
def tree_big(m):
    """Three blocks tall: a short tapered trunk and a big crown of soft clumps."""
    m.limb((1.0, 0.5, 0.0), (1.0, 0.5, 1.1), 0.16, 'trunk')
    m.limb((1.0, 0.5, 0.8), (0.65, 0.45, 1.3), 0.08, 'trunk'); m.limb((1.0, 0.5, 0.9), (1.35, 0.5, 1.4), 0.08, 'trunk')
    rnd = random.Random(7)
    for i, (x, z, r) in enumerate([(1.0, 2.1, 0.62), (0.55, 1.75, 0.48), (1.45, 1.75, 0.48), (0.7, 2.45, 0.42), (1.3, 2.45, 0.42),
                                   (1.0, 1.45, 0.5), (0.4, 1.35, 0.32), (1.6, 1.35, 0.32), (1.0, 2.7, 0.36)]):
        m.clump(x, 0.5 + rnd.uniform(-0.1, 0.1), z, r, ('leaf', 'leaf_lt', 'leaf')[i % 3], seed=i)
    return 2.0, 1.0

def tree_small(m):
    m.limb((0.5, 0.4, 0.0), (0.5, 0.4, 0.95), 0.08, 'trunk')
    for i, (x, z, r) in enumerate([(0.5, 1.45, 0.34), (0.3, 1.2, 0.25), (0.7, 1.2, 0.25), (0.5, 1.75, 0.22), (0.5, 1.05, 0.26)]):
        m.clump(x, 0.4, z, r, ('leaf', 'leaf_lt')[i % 2], seed=20 + i)
    return 1.0, 0.8

def bush(m):
    for i, (x, z, r) in enumerate([(0.5, 0.36, 0.32), (0.25, 0.25, 0.22), (0.75, 0.25, 0.22), (0.5, 0.2, 0.25)]):
        m.clump(x, 0.45, z, r, ('leaf', 'leaf_lt', 'leaf', 'leaf_dk')[i], seed=40 + i)
    rnd = random.Random(3)
    for i in range(7):
        a = rnd.uniform(0, math.pi); z = rnd.uniform(0.2, 0.55)
        m.ball(0.5 + 0.3 * math.cos(a), 0.2, z, 0.035, 'berry')
    return 1.0, 0.8

def rock(m):
    m.clump(0.5, 0.45, 0.16, 0.3, 'rock', seed=60, rough=0.35, sz=0.62, flat=True)
    m.clump(0.24, 0.32, 0.08, 0.15, 'rock_dk', seed=61, rough=0.35, sz=0.6, flat=True)
    m.clump(0.2, 0.15, 0.02, 0.07, 'leaf', seed=62); m.clump(0.82, 0.2, 0.02, 0.06, 'leaf', seed=63)
    return 1.0, 0.8

def fence(m):
    """A white picket fence, one cell long: two rails run edge to edge so pieces join, pickets with pointed tops."""
    for z in (0.22, 0.52): m.box(0, 0.48, z, 1.0, 0.53, z + 0.07, key='trim')
    for x in (0.125, 0.375, 0.625, 0.875):
        m.box(x - 0.07, 0.42, 0, x + 0.07, 0.48, 0.66, key='trim', bevel=0.008)
        m.gable(x - 0.07, 0.42, x + 0.07, 0.48, 0.66, 0.7, key='trim')
    return 1.0, 1.0

def coop(m):
    """3 x 3 cells, three blocks to the ridge: white board walls, a blue shingle roof, a wooden door with a ramp, a round window."""
    m.box(0.25, 0.7, 0, 2.75, 2.7, 0.14, key='stone', bevel=0.02)
    m.box(0.3, 0.75, 0.14, 2.7, 2.65, 1.7, key='trim')
    for z in [0.14 + 0.13 * i for i in range(1, 12)]: m.box(0.3, 0.735, z - 0.008, 2.7, 0.75, z, key='wall_dk')   # board lines
    for x in (0.3, 2.62): m.box(x, 0.72, 0.14, x + 0.08, 0.8, 1.7, key='wood_lt')
    m.gable(0.12, 0.5, 2.88, 2.9, 1.6, 2.8, key='roof')
    for k in range(1, 6):                                                                 # shingle edges down the front slope
        t = k / 6
        m.limb((0.12, 1.7 - t * 1.2, 2.8 - t * 1.2 + 0.03), (2.88, 1.7 - t * 1.2, 2.8 - t * 1.2 + 0.03), 0.028, 'roof_lt')
    m.box(0.1, 1.66, 2.74, 2.9, 1.74, 2.86, key='trim', bevel=0.02)
    m.box(1.12, 0.69, 0.14, 1.88, 0.74, 1.18, key='wood', bevel=0.015)
    m.box(1.08, 0.68, 1.15, 1.92, 0.74, 1.24, key='trim')
    for x in (1.32, 1.5, 1.68): m.box(x - 0.01, 0.68, 0.2, x + 0.01, 0.69, 1.1, key='wood_dk')
    m.box(1.2, 0.05, 0.0, 1.8, 0.7, 0.07, key='wood_lt', bevel=0.01)
    m.disc_front(2.2, 0.72, 1.3, 0.18, 0.05, 'wood_lt'); m.disc_front(2.2, 0.7, 1.3, 0.13, 0.05, 'glass')
    m.disc_front(0.75, 0.72, 0.8, 0.15, 0.04, 'wood'); m.disc_front(0.75, 0.70, 0.8, 0.1, 0.04, 'wood_dk')
    m.ball(2.3, 0.3, 0.12, 0.11, 'trim', 1.2, 0.9, 0.9); m.ball(2.4, 0.26, 0.24, 0.07, 'trim')   # a hen
    m.box(2.44, 0.18, 0.21, 2.49, 0.22, 0.24, key='gold'); m.ball(2.4, 0.25, 0.32, 0.03, 'red')
    return 3.0, 3.0

# Crops stand on a 2 x 2 cell plot that the game draws flat (square on screen). A plant `r` cells from the front on screen stands
# r / sin(tilt) cells deep in the world, so its foot lands on the right row of the flat plot.
DEEP = 1 / math.sin(TILT)
SPOTS = [(x, r) for r in (1.62, 1.0, 0.38) for x in (0.38, 1.0, 1.62)]

def crop(kind, stage):
    def build(m):
        rnd = random.Random(stage * 10 + len(kind))
        for i, (x, r) in enumerate(SPOTS):
            x += rnd.uniform(-0.04, 0.04); y = r * DEEP
            if stage == 1:
                m.limb((x, y, 0), (x, y, 0.1), 0.012, 'stem')
                for s in (-1, 1): m.ball(x + s * 0.05, y, 0.11, 0.045, 'leaf_lt', 1.4, 0.6, 0.5)
                continue
            if kind == 'wheat':
                hgt = (0, 0, 0.35, 0.65, 0.75)[stage]
                for k in range(5):
                    a = k * 1.26; dx = 0.07 * math.cos(a); top = (x + dx * 1.6, y + 0.05 * math.sin(a), hgt)
                    m.limb((x + dx * 0.5, y, 0), top, 0.012, 'stem' if stage < 4 else 'gold_dk')
                    if stage >= 3: m.ball(top[0], top[1], top[2] + 0.06, 0.03, 'stem' if stage == 3 else 'gold', 1, 1, 3.2)
            elif kind == 'tomato':
                s = (0, 0, 0.16, 0.24, 0.27)[stage]
                m.limb((x, y, 0), (x, y, s * 2.2), 0.012, 'wood_dk')
                for k, (dx, dz) in enumerate([(0, 1.5), (-0.7, 1.0), (0.7, 1.0), (0, 0.6)]):
                    m.clump(x + dx * s * 0.7, y, dz * s, s * 0.75, ('leaf', 'leaf_lt')[k % 2], seed=i * 4 + k)
                if stage >= 3:
                    for dx, dz in ((-0.5, 0.9), (0.6, 1.2), (0.1, 0.55), (-0.2, 1.5)):
                        m.ball(x + dx * s, y - s * 0.6, dz * s, 0.055, 'stem' if stage == 3 else 'red')
            else:
                s = (0, 0, 0.13, 0.2, 0.26)[stage]
                for k in range(6):
                    a = k * 1.05
                    m.ball(x + s * 0.8 * math.cos(a), y + s * 0.5 * math.sin(a), s * 0.35, s * 0.7, 'leaf_lt' if k % 2 else 'leaf', 1.2, 1.0, 0.45)
                if stage >= 3: m.ball(x, y, s * 0.75, s * 0.75, 'cabbage' if stage == 3 else 'cabbage_lt')
        return 2.0, 2.0 * DEEP
    return build

def soil(wet):
    """The tilled bed, seen straight down: five rounded ridges with furrows between, inside a darker rim."""
    def build(m):
        top, dk = ('soil', 'soil_dk') if not wet else ('soil_wet', 'soil_wet_dk')
        m.box(0.02, 0.02, -0.06, 1.98, 1.98, 0.0, key=dk, bevel=0.05)
        for i in range(5):
            y = 0.2 + i * 0.4
            m.limb((0.12, y, 0.0), (1.88, y, 0.0), 0.13, top)
        return 2.0, 2.0
    return build

# ======================================================================== rendering
# name: (folder, builder, turns, size (w, h) px, camera: 'tilt' or 'down', base: px below the foot line in the picture)
JOBS = {
    'rest_table_small_01': ('furniture', table, 0, (192, 128), 'tilt', 0),
    'rest_stove_01': ('furniture', stove, 0, (192, 160), 'tilt', 0),
    'rest_stove_side_01': ('furniture', stove, 1, (128, 224), 'tilt', 0),
    'rest_stove_back_01': ('furniture', stove, 2, (192, 160), 'tilt', 0),
    'rest_vase_small_01': ('furniture', vase_small, 0, (64, 64), 'tilt', 0),
    'rest_vase_large_01': ('furniture', vase_large, 0, (128, 128), 'tilt', 0),
    'wall_plain_01': ('walls', wall, 0, (128, 384), 'front', 0),
    'wall_low_01': ('walls', lambda m: wall(m, True), 0, (128, 64), 'front', 0),
    'wall_side_01': ('walls', wall_side, 0, (48, 384), 'front', 0),
    'wdeco_door_01': ('walls', door, 0, (128, 280), 'front', 24),
    'wdeco_door_open_01': ('walls', lambda m: door(m, True), 0, (128, 280), 'front', 24),
    'wdeco_window_01': ('walls', window, 0, (128, 128), 'front', 0),
    'wdeco_painting_01': ('walls', painting, 0, (128, 128), 'front', 0),
    'obs_tree_01': ('obstacles', tree_big, 0, (256, 512), 'tilt', 0),
    'obs_tree_02': ('obstacles', tree_small, 0, (128, 256), 'tilt', 0),
    'obs_bush_01': ('obstacles', bush, 0, (128, 128), 'tilt', 0),
    'obs_rock_01': ('obstacles', rock, 0, (128, 96), 'tilt', 0),
    'farm_fence_01': ('farm', fence, 0, (128, 160), 'tilt', 0),
    'farm_coop_01': ('farm', coop, 0, (384, 576), 'tilt', 0),
    'tile_soil_dry_01': ('farm', soil(False), 0, (256, 256), 'down', 0),
    'tile_soil_wet_01': ('farm', soil(True), 0, (256, 256), 'down', 0),
}
for _k in ('wheat', 'tomato', 'cabbage'):
    for _s in range(1, 5):
        JOBS['crop_%s_s%d' % (_k, _s)] = ('farm', crop(_k, _s), 0, (256, 256), 'tilt', 0)

def scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    R._mats.clear()
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'; sc.cycles.samples = 48; sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
    sc.render.filter_size = 1.2
    world = bpy.data.worlds.new('w'); sc.world = world; world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (0.78, 0.86, 1.0, 1); bg.inputs['Strength'].default_value = 0.75   # cool sky fill
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 3.2; sun.data.angle = math.radians(30); sun.data.color = (1.0, 0.95, 0.86)              # warm sun from the top left
    sun.rotation_euler = (math.radians(48), math.radians(-30), math.radians(-25))
    sc.collection.objects.link(sun)
    return sc

def render(name, out):
    folder, build, turns, (wpx, hpx), cam_kind, base = JOBS[name]
    sc = scene()
    m = M()
    w, d = build(m)
    m.root.location = (w / 2, d / 2, 0)
    for ch in m.root.children: ch.location.x -= w / 2; ch.location.y -= d / 2
    m.root.rotation_euler.z = -math.pi / 2 * turns
    fw, fd = (d, w) if turns % 2 else (w, d)
    m.root.location = (fw / 2, fd / 2, 0)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = max(wpx, hpx) / PX
    sc.collection.objects.link(cam); sc.camera = cam
    if cam_kind == 'down':
        cam.location = (fw / 2, fd / 2, 30); cam.rotation_euler = (0, 0, 0)
        # straight down the picture's top is +y (the back): flip so the back is at the top of the picture
    else:
        tilt = TILT if cam_kind == 'tilt' else TILT
        look = Vector((0, math.cos(tilt), -math.sin(tilt))); up = Vector((0, math.sin(tilt), math.cos(tilt)))
        centre = Vector((fw / 2, 0, 0)) + up * ((hpx / 2 - base) / PX)
        cam.location = centre - look * 30; cam.rotation_euler = (math.pi / 2 - tilt, 0, 0)
    sc.render.resolution_x, sc.render.resolution_y = wpx * SS, hpx * SS
    raw = os.path.join(out, '_raw_' + name + '.png')
    sc.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    im = Image.open(raw).convert('RGBa').resize((wpx, hpx), Image.LANCZOS).convert('RGBA')
    os.makedirs(os.path.join(out, folder), exist_ok=True)
    im.save(os.path.join(out, folder, name + '.png'))
    os.remove(raw)

if __name__ == '__main__':
    args = [a for a in sys.argv[1:]]
    out = os.path.abspath(args[0] if args else 'assets/td')
    only = set(args[1:])
    for name in JOBS:
        if not only or name in only:
            render(name, out); print('rendered', name)
