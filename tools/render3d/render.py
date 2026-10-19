#!/usr/bin/env python3
"""Pilot: furniture and a character built as simple 3D models in Blender, rendered from the game's camera, one picture per facing.
Every piece is rendered in the same world (1 Blender unit = 1 cell = 32 px, heights in blocks), so sizes always agree, and turning a piece
is just turning the model. pixelize.py then turns the renders into palette pixel art.
Needs Blender as a Python module (Python 3.11):  uv venv -p 3.11 .bpyenv && uv pip install -p .bpyenv/bin/python bpy pillow
.bpyenv/bin/python tools/render3d/render.py [OUTDIR]     (default assets/td/art_workshop/pilot/render3d/raw)"""
import sys, os, math
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'pixelart'))
from palette import P

# Camera: looking down 22 degrees, so a cell of depth shows as 12 px of top (sin 22 = 0.375) like the hand-drawn pilot pieces.
# Heights are stretched by 1 / cos(22) so one block of height is exactly 32 px on screen (the game's rule: 32 px per block).
TILT = math.asin(0.375)
ZS = 1 / math.cos(TILT)
PX = 32          # pixels per cell in the final art
SS = 8           # render this many times bigger, pixelize.py shrinks it

def lin(c):
    """Palette colour (sRGB 0..255) to the linear values Blender materials take."""
    def f(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (f(c[0]), f(c[1]), f(c[2]), 1)

_mats = {}
def mat(key, rough=0.8):
    """A material from a palette key ('w4') or a colour ('#c98a55')."""
    if key not in _mats:
        m = bpy.data.materials.new(key)
        m.use_nodes = True
        b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = lin(P[key] if not key.startswith('#') else tuple(int(key[i:i + 2], 16) for i in (1, 3, 5)))
        b.inputs['Roughness'].default_value = rough
        _mats[key] = m
    return _mats[key]

# ---------- building blocks (x right, y away from the viewer, z up; z in blocks, scaled by ZS here) ----------
class Model:
    def __init__(self):
        self.root = bpy.data.objects.new('root', None)
        bpy.context.collection.objects.link(self.root)
    def _own(self, ob, key):
        ob.data.materials.append(mat(key))
        ob.parent = self.root
        return ob
    def box(self, x0, y0, z0, x1, y1, z1, key, bevel=0.0):
        bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2 * ZS))
        ob = bpy.context.object
        ob.scale = (x1 - x0, y1 - y0, (z1 - z0) * ZS)
        if bevel:
            bpy.ops.object.transform_apply(scale=True)
            m = ob.modifiers.new('b', 'BEVEL'); m.width = bevel; m.segments = 2
        return self._own(ob, key)
    def cyl(self, x, y, z0, z1, r, key, verts=16):
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=(z1 - z0) * ZS, location=(x, y, (z0 + z1) / 2 * ZS))
        return self._own(bpy.context.object, key)
    def disc_front(self, x, y, z, r, depth, key, verts=20):
        """A disc facing the viewer (a knob, a button): its axis along y."""
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=(x, y, z * ZS), rotation=(math.pi / 2, 0, 0))
        ob = bpy.context.object; ob.scale.y = ZS
        return self._own(ob, key)
    def ball(self, x, y, z, r, key, sx=1, sy=1, sz=1):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=r, location=(x, y, z * ZS))
        ob = bpy.context.object; ob.scale = (sx, sy, sz * ZS)
        bpy.ops.object.shade_smooth()
        return self._own(ob, key)
    def gable(self, x0, y0, x1, y1, z0, z1, key):
        """A roof: ridge along x at the middle of y, eaves at z0, ridge at z1 (a prism)."""
        ym = (y0 + y1) / 2
        v = [(x0, y0, z0 * ZS), (x1, y0, z0 * ZS), (x1, ym, z1 * ZS), (x0, ym, z1 * ZS), (x0, y1, z0 * ZS), (x1, y1, z0 * ZS)]
        f = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5, 1)]
        me = bpy.data.meshes.new('roof'); me.from_pydata(v, [], f); me.update()
        ob = bpy.data.objects.new('roof', me); bpy.context.collection.objects.link(ob)
        return self._own(ob, key)
    def limb(self, a, b, r, key):
        """A cylinder from point a to point b (z in blocks)."""
        a = Vector((a[0], a[1], a[2] * ZS)); b = Vector((b[0], b[1], b[2] * ZS))
        d = b - a
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=r, depth=d.length, location=(a + b) / 2)
        ob = bpy.context.object
        ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = d.to_track_quat('Z', 'Y')
        bpy.ops.object.shade_smooth()
        return self._own(ob, key)

# ---------- pieces: each is built facing the viewer (front at y = 0) on a footprint w x d cells ----------
def table(m):
    """1.5 x 1 cells, waist-low (0.62 blocks): two planks on top, four legs."""
    w, d, top = 1.5, 1.0, 0.62
    m.box(0, 0, top - 0.12, w, d / 2 - 0.006, top, 'w4', 0.01)
    m.box(0, d / 2 + 0.006, top - 0.12, w, d, top, 'w5', 0.01)
    m.box(0.02, 0.02, top - 0.2, w - 0.02, d - 0.02, top - 0.12, 'w2')                 # apron under the top
    for x in (0.07, w - 0.25):
        for y in (0.07, d - 0.25): m.box(x, y, 0, x + 0.18, y + 0.18, top - 0.12, 'w2')
    return w, d

def stove(m):
    """1.5 x 1 cells, a block tall with a tiled back splash: two burners on top, an oven door with a window and a brass handle."""
    w, d, h = 1.5, 1.0, 0.72
    m.box(0, 0, 0, w, d, h, 'c2', 0.015)
    m.box(0.04, 0.12, h, w - 0.04, d - 0.12, h + 0.01, 's0')                             # cooking plate
    for x in (0.42, w - 0.42):
        m.cyl(x, 0.5, h, h + 0.04, 0.16, 's1'); m.cyl(x, 0.5, h + 0.03, h + 0.05, 0.09, 's2', 12)
    m.box(0, d - 0.09, h, w, d, h + 0.17, 'c3')                                          # back splash
    m.box(0.1, -0.02, 0.06, w - 0.1, 0.0, 0.52, 'b1')                                     # oven door
    m.box(0.22, -0.03, 0.14, w - 0.22, -0.02, 0.4, 's0')                                  # its window
    m.box(0.2, -0.07, 0.45, w - 0.2, -0.04, 0.48, 'r1')                                   # handle
    for x in (0.28, 0.5, w - 0.5, w - 0.28): m.disc_front(x, -0.015, 0.62, 0.035, 0.03, 'r1', 12)   # knobs
    return w, d

def chair(m):
    """Fits a cell: seat at knee height (0.4), back rest to chest height (0.8) at the back of the seat."""
    w, d, s = 1.0, 0.6, 0.4
    x0, x1 = 0.2, 0.8
    m.box(x0, 0, s - 0.07, x1, d, s, 'w5', 0.01)                                          # seat
    for x in (x0 + 0.02, x1 - 0.1):
        for y in (0.03, d - 0.11): m.box(x, y, 0, x + 0.08, y + 0.08, s - 0.07, 'w2')
    for x in (x0 + 0.02, x1 - 0.1): m.box(x, d - 0.1, s, x + 0.08, d - 0.02, 0.82, 'w3')   # back posts
    m.box(x0 + 0.03, d - 0.095, 0.66, x1 - 0.03, d - 0.025, 0.8, 'w3')                   # back rail, just inside the posts (no shared faces)
    for x in (0.38, 0.47, 0.56): m.box(x, d - 0.09, s, x + 0.05, d - 0.03, 0.66, 'w2')      # spindles
    return w, d

def character(m, frame=0):
    """A three-head chibi cook, about 1.8 blocks tall: head a third of the height. frame 0..3 = stand, step, stand, step."""
    w, d = 1.0, 0.5
    cx, cy = 0.5, 0.25
    swing = (0, 0.1, 0, -0.1)[frame]
    bob = 0.02 if frame in (1, 3) else 0
    for side, sgn in ((-1, 1), (1, -1)):                                                   # legs and shoes, swinging opposite ways
        x = cx + side * 0.08; f = swing * sgn
        lift = 0.07 if f < 0 else 0                                                        # the foot swinging back is off the ground
        m.limb((x, cy, 0.54 + bob), (x, cy - f, 0.1 + lift), 0.07, 'b0')
        m.ball(x, cy - f - 0.03, 0.06 + lift, 0.085, 'w1', 1, 1.4, 0.6)
    m.ball(cx, cy, 0.78 + bob, 0.21, 'b3', 1.05, 0.95, 1.3)                                  # body (shirt)
    m.limb((cx, cy, 0.95 + bob), (cx, cy, 1.2 + bob), 0.07, 'k0')                          # neck
    m.box(cx - 0.13, cy - 0.2, 0.5 + bob, cx + 0.13, cy - 0.15, 0.9 + bob, 'c4')        # apron
    for side, sgn in ((-1, -1), (1, 1)):                                                   # arms swing against the legs
        x = cx + side * 0.19; f = swing * sgn
        m.limb((x, cy, 0.98 + bob), (x + side * 0.03, cy - f, 0.64 + bob), 0.055, 'b3')
        m.ball(x + side * 0.03, cy - f, 0.61 + bob, 0.06, 'k1')
    hz = 1.44 + bob                                                                        # head and face
    m.ball(cx, cy, hz, 0.31, 'k1')
    m.ball(cx, cy + 0.04, hz + 0.07, 0.32, 'h1', 1.02, 1.0, 0.92)                          # hair cap, behind and above the face
    m.ball(cx, cy - 0.18, hz + 0.19, 0.2, 'h1', 1.4, 0.6, 0.45)                            # fringe
    for side in (-1, 1):
        m.ball(cx + side * 0.11, cy - 0.27, hz - 0.03, 0.045, 'e0', 1, 0.5, 1.3)           # eyes
        m.ball(cx + side * 0.17, cy - 0.25, hz - 0.1, 0.04, 'p1', 1.2, 0.4, 0.7)           # blush
    return w, d

def coop(m):
    """3 x 3 cells, three blocks tall to the ridge: cream walls, a blue gable roof, a wooden door with a ramp, a round window."""
    w, d = 3.0, 3.0
    m.box(0.25, 0.7, 0, 2.75, 2.7, 0.12, 'u2')                                           # stone footing
    m.box(0.3, 0.75, 0.12, 2.7, 2.65, 1.7, 'c3')                                          # walls
    for x in (0.3, 2.62): m.box(x, 0.73, 0.12, x + 0.08, 0.81, 1.7, 'c4')                 # corner boards
    for k in range(5):                                                                    # roof: five shingle rows, each a step up the slope
        t = k / 5
        m.gable(0.15, 0.55 + t * 1.1, 2.85, 2.85 - t * 1.1, 1.62 + t * 1.13, 2.75, ('b2', 'b3')[k % 2])
    m.box(0.12, 1.66, 2.68, 2.88, 1.74, 2.8, 'c4')                                        # ridge cap
    m.box(0.15, 0.53, 1.58, 2.85, 0.6, 1.66, 'c4')                                        # white eave trim
    m.box(1.15, 0.7, 0.12, 1.85, 0.75, 1.15, 'w3')                                        # door
    m.box(1.12, 0.68, 1.12, 1.88, 0.74, 1.2, 'c4')
    for x in (1.33, 1.5, 1.67): m.box(x, 0.69, 0.18, x + 0.02, 0.7, 1.08, 'w2')
    m.box(1.2, 0.1, 0.0, 1.8, 0.7, 0.08, 'w4')                                            # ramp
    m.disc_front(2.2, 0.72, 1.3, 0.16, 0.04, 'c4', 20); m.disc_front(2.2, 0.7, 1.3, 0.11, 0.04, 'g1', 20)   # round window
    m.disc_front(0.75, 0.72, 0.75, 0.13, 0.04, 'w4', 12)                                  # nest box hole
    m.disc_front(0.75, 0.70, 0.75, 0.09, 0.04, 'w0', 12)
    return w, d

# Each output: (file name, builder, facing turns: 0 front, 1 left, 2 back, size in px (w, h), frame)
JOBS = [
    ('rest_table_small_01', table, 0, (48, 32), 0),
    ('rest_stove_01', stove, 0, (48, 40), 0),
    ('rest_stove_side_01', stove, 1, (32, 56), 0),
    ('rest_stove_back_01', stove, 2, (48, 40), 0),
    ('chair_front', chair, 0, (32, 32), 0),
    ('chair_side', chair, 1, (32, 32), 0),
    ('chair_back', chair, 2, (32, 32), 0),
    ('farm_coop_01', coop, 0, (96, 144), 0),
] + [('cook_down_%d' % f, character, 0, (32, 64), f) for f in range(4)] + [
    ('cook_left_0', character, 1, (32, 64), 0), ('cook_up_0', character, 2, (32, 64), 0),
]

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'; sc.cycles.samples = 128; sc.cycles.use_denoising = False
    sc.render.film_transparent = True
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    sc.render.filter_size = 0.8
    world = bpy.data.worlds.new('w'); sc.world = world
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (1, 1, 1, 1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.55
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 2.6; sun.data.angle = math.radians(25)
    sun.rotation_euler = (math.radians(50), math.radians(-28), math.radians(-25))         # light from the top left, a little in front
    sc.collection.objects.link(sun)
    return sc

def render(name, build, turns, size, frame, out):
    sc = reset()
    m = Model()
    w, d = build(m, frame) if build is character else build(m)
    # turn the model about its footprint centre, then move its footprint back to start at (0, 0)
    m.root.location = (w / 2, d / 2, 0)
    for ch in m.root.children: ch.location.x -= w / 2; ch.location.y -= d / 2
    m.root.rotation_euler.z = -math.pi / 2 * turns                                         # front (-y) -> left (-x) -> back (+y)
    fw, fd = (d, w) if turns % 2 else (w, d)
    m.root.location = (fw / 2, fd / 2, 0)
    # camera: the front bottom edge of the footprint sits on the bottom row; the footprint is centred across
    wpx, hpx = size
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = max(wpx, hpx) / PX
    sc.collection.objects.link(cam); sc.camera = cam
    look = Vector((0, math.cos(TILT), -math.sin(TILT))); up = Vector((0, math.sin(TILT), math.cos(TILT)))
    centre = Vector((fw / 2, 0, 0)) + up * (hpx / PX / 2)
    cam.location = centre - look * 30
    cam.rotation_euler = (math.pi / 2 - TILT, 0, 0)
    sc.render.resolution_x, sc.render.resolution_y = wpx * SS, hpx * SS
    sc.render.filepath = os.path.join(out, name + '.png')
    bpy.ops.render.render(write_still=True)

if __name__ == '__main__':
    out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else 'assets/td/art_workshop/pilot/render3d/raw')
    os.makedirs(out, exist_ok=True)
    only = set(sys.argv[2:])
    for job in JOBS:
        if not only or job[0] in only:
            render(*job, out); print('rendered', job[0])
