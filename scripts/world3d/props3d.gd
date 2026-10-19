class_name Props3D
extends RefCounted

# The 3D look of everything that stands in the world, built from simple shapes into a MeshBatch.
# One world unit is one cell (1 m). A model is built around the middle of its footprint on the ground, its front towards +z
# (the camera); `turn` quarter-turns it like the game's facing (0 front, 1 left, 2 back, 3 right).

const WOOD := Color("c98a55")
const WOOD_LT := Color("dba06a")
const WOOD_DK := Color("8b5a36")
const CREAM := Color("f4e9d6")
const WHITE := Color("fbf7ef")
const BLUE := Color("3d7fb8")
const BLUE_DK := Color("2c5f8f")
const STEEL := Color("3a4049")
const BRASS := Color("e4b464")
const GLASS := Color("b7e0ee")
const LEAF := Color("5d9e45")
const LEAF_LT := Color("86c25a")
const LEAF_DK := Color("3f7d3a")
const TRUNK := Color("8a5a3a")
const ROCK := Color("a59c90")
const SOIL := Color("7a4f31")
const SOIL_DK := Color("5c3b25")
const RED := Color("d9483b")
const GOLD := Color("e8c35a")
const STEM := Color("6a9a3e")
const ROOF := Color("3c79b2")

# Draws in a model's own space: x across, y up, z towards the front.
class Pen:
	var b: MeshBatch
	var xf: Transform3D
	func _init(batch: MeshBatch, at: Vector3, turn: int = 0) -> void:
		b = batch
		xf = Transform3D(Basis(Vector3.UP, -PI * 0.5 * turn), at)
	func box(lo: Vector3, hi: Vector3, col: Color) -> void:
		b.add("box", xf * Transform3D(Basis.from_scale(hi - lo), (lo + hi) * 0.5), col)
	func ball(c: Vector3, r: Vector3, col: Color, lumpy: float = 0.0, seed: int = 0) -> void:
		b.add("ball", xf * Transform3D(Basis.from_scale(r * 2.0), c), col, lumpy, seed)
	func cyl(bottom: Vector3, r: float, h: float, col: Color) -> void:
		b.add("cyl", xf * Transform3D(Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), bottom + Vector3(0, h * 0.5, 0)), col)
	func cone(bottom: Vector3, r: float, h: float, col: Color) -> void:
		b.add("cone", xf * Transform3D(Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), bottom + Vector3(0, h * 0.5, 0)), col)
	func rod(a: Vector3, c: Vector3, r: float, col: Color) -> void:
		b.rod(xf * a, xf * c, r, col)
	# A slab tilted about x (a roof slope, a leaning board): centre, size, angle in radians.
	func tilted(centre: Vector3, size: Vector3, angle: float, col: Color) -> void:
		b.add("box", xf * Transform3D(Basis(Vector3.RIGHT, angle) * Basis.from_scale(size), centre), col)

# ------------------------------------------------------------------ shop
static func table(b: MeshBatch, at: Vector3, w: float, d: float, turn: int) -> void:
	var p := Pen.new(b, at, turn)
	var top := 0.55
	p.box(Vector3(-w * 0.5, top - 0.06, -d * 0.5), Vector3(w * 0.5, top, d * 0.5), WOOD_LT)
	p.box(Vector3(-w * 0.5 + 0.05, top - 0.12, -d * 0.5 + 0.05), Vector3(w * 0.5 - 0.05, top - 0.06, d * 0.5 - 0.05), WOOD)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			p.cyl(Vector3(sx * (w * 0.5 - 0.1), 0, sz * (d * 0.5 - 0.1)), 0.04, top - 0.06, WOOD_DK)
	for sx in [-1.0, 1.0]:                                                    # a stool at each end, where the guests sit
		var sxp: float = sx * (w * 0.5 + 0.28)
		p.cyl(Vector3(sxp, 0, 0), 0.05, 0.32, WOOD_DK)
		p.cyl(Vector3(sxp, 0.32, 0), 0.17, 0.05, Color("e86f5a"))

static func stove(b: MeshBatch, at: Vector3, w: float, d: float, turn: int) -> void:
	var p := Pen.new(b, at, turn)
	var h := 0.78
	p.box(Vector3(-w * 0.5, 0.05, -d * 0.5), Vector3(w * 0.5, h, d * 0.5 - 0.02), CREAM)
	p.box(Vector3(-w * 0.5 + 0.02, 0, -d * 0.5 + 0.02), Vector3(w * 0.5 - 0.02, 0.05, d * 0.5 - 0.04), STEEL)
	p.box(Vector3(-w * 0.5 + 0.04, h, -d * 0.5 + 0.14), Vector3(w * 0.5 - 0.04, h + 0.015, d * 0.5 - 0.06), STEEL)
	for sx in [-0.27, 0.27]:
		p.cyl(Vector3(sx * w, h, 0.02), 0.15, 0.03, Color("5d6773"))
		p.cyl(Vector3(sx * w, h + 0.02, 0.02), 0.08, 0.02, STEEL)
	p.box(Vector3(-w * 0.5, h, -d * 0.5), Vector3(w * 0.5, h + 0.28, -d * 0.5 + 0.08), WHITE)   # tiled back splash
	p.box(Vector3(-w * 0.5 + 0.1, 0.12, d * 0.5 - 0.02), Vector3(w * 0.5 - 0.1, 0.55, d * 0.5 + 0.01), BLUE)
	p.box(Vector3(-w * 0.5 + 0.22, 0.2, d * 0.5), Vector3(w * 0.5 - 0.22, 0.45, d * 0.5 + 0.02), STEEL)
	p.rod(Vector3(-w * 0.5 + 0.15, 0.5, d * 0.5 + 0.06), Vector3(w * 0.5 - 0.15, 0.5, d * 0.5 + 0.06), 0.02, BRASS)
	for sx in [-0.38, -0.18, 0.18, 0.38]:
		p.ball(Vector3(sx * w, 0.66, d * 0.5 + 0.01), Vector3(0.04, 0.04, 0.03), BRASS)

static func vase(b: MeshBatch, at: Vector3, big: bool) -> void:
	var p := Pen.new(b, at)
	var s := 1.0 if big else 0.55
	p.ball(Vector3(0, 0.12 * s, 0), Vector3(0.12, 0.13, 0.12) * s, WHITE)
	p.cyl(Vector3(0, 0.08 * s, 0), 0.121 * s, 0.03 * s, BLUE)
	p.cyl(Vector3(0, 0.2 * s, 0), 0.05 * s, 0.08 * s, WHITE)
	for i in 5:
		var a := i * 1.256
		var tip := Vector3(cos(a) * 0.07, 0.38, sin(a) * 0.05) * s
		p.rod(Vector3(0, 0.25 * s, 0), tip, 0.008, STEM)
		p.ball(tip, Vector3.ONE * 0.035 * s, [RED, GOLD, WHITE][i % 3])

# A cutaway wall piece along x, from x0 to x1 at z, its room side towards +z. kind: wall, window, door, low.
static func wall(b: MeshBatch, x0: float, x1: float, z: float, kind: String, along_z: bool = false) -> void:
	var H := 2.4
	var T := 0.12
	var seg := func(a: float, c: float, y0: float, y1: float, col: Color, inset: float = 0.0) -> void:
		if along_z:
			b.box(Vector3(z - T * 0.5 + inset, y0, a), Vector3(z + T * 0.5 + inset, y1, c), col)
		else:
			b.box(Vector3(a, y0, z - T * 0.5 + inset), Vector3(c, y1, z + T * 0.5 + inset), col)
	if kind == "low":
		seg.call(x0, x1, 0.0, 0.45, BLUE)
		seg.call(x0, x1, 0.45, 0.5, WHITE)
		return
	var room := 0.07   # the blue wainscot sits proud of the room side
	match kind:
		"window":
			seg.call(x0, x1, 0.0, 0.9, CREAM)
			seg.call(x0, x1, 1.85, H, CREAM)
			seg.call(x0, x0 + 0.12, 0.9, 1.85, WHITE); seg.call(x1 - 0.12, x1, 0.9, 1.85, WHITE)
			seg.call(x0, x1, 0.86, 0.94, WHITE, 0.03); seg.call(x0, x1, 1.8, 1.88, WHITE)
			seg.call(x0 + 0.12, x1 - 0.12, 0.94, 1.8, GLASS.lerp(Color.WHITE, 0.2), -0.02)
		"door":
			seg.call(x0, x1, 2.05, H, CREAM)
			seg.call(x0, x0 + 0.08, 0.0, 2.05, WHITE); seg.call(x1 - 0.08, x1, 0.0, 2.05, WHITE)
		_:
			seg.call(x0, x1, 0.0, H, CREAM)
	if kind != "door":
		seg.call(x0, x1, 0.0, 0.85, BLUE, room)
		seg.call(x0, x1, 0.85, 0.92, WHITE, room + 0.01)
	seg.call(x0, x1, H - 0.08, H, WHITE, 0.02)

# ------------------------------------------------------------------ garden
static func plot(b: MeshBatch, at: Vector3, w: float, d: float, crop: String, stage: int) -> void:
	var p := Pen.new(b, at)
	p.box(Vector3(-w * 0.5 + 0.04, 0, -d * 0.5 + 0.04), Vector3(w * 0.5 - 0.04, 0.06, d * 0.5 - 0.04), SOIL_DK)
	for i in 4:
		var z := -d * 0.5 + 0.25 + i * (d - 0.5) / 3.0
		p.rod(Vector3(-w * 0.5 + 0.12, 0.07, z), Vector3(w * 0.5 - 0.12, 0.07, z), 0.08, SOIL)
	if crop == "" or stage <= 0:
		return
	var rnd := 0
	for zi in 3:
		for xi in 3:
			rnd += 1
			var c := Vector3(-w * 0.5 + w * (xi + 0.5) / 3.0, 0.1, -d * 0.5 + d * (zi + 0.5) / 3.0)
			_plant(p, c, crop, stage, rnd)

static func _plant(p: Pen, c: Vector3, crop: String, stage: int, seed: int) -> void:
	if stage == 1:
		p.rod(c, c + Vector3(0, 0.08, 0), 0.01, STEM)
		p.ball(c + Vector3(-0.04, 0.09, 0), Vector3(0.05, 0.015, 0.03), LEAF_LT)
		p.ball(c + Vector3(0.04, 0.1, 0), Vector3(0.05, 0.015, 0.03), LEAF_LT)
		return
	match crop:
		"wheat":
			var h: float = [0.0, 0.0, 0.25, 0.45, 0.55][stage]
			for k in 5:
				var a := k * 1.26
				var tip := c + Vector3(cos(a) * 0.07, h, sin(a) * 0.05)
				p.rod(c + Vector3(cos(a) * 0.02, 0, 0), tip, 0.008, STEM if stage < 4 else Color("c99a35"))
				if stage >= 3:
					p.ball(tip + Vector3(0, 0.05, 0), Vector3(0.025, 0.07, 0.025), STEM.lerp(GOLD, 0.4) if stage == 3 else GOLD)
		"tomato":
			var s: float = [0.0, 0.0, 0.12, 0.17, 0.19][stage]
			p.rod(c, c + Vector3(0, s * 2.6, 0), 0.01, WOOD_DK)                 # a cane
			p.ball(c + Vector3(0, s * 1.4, 0), Vector3(s, s * 1.2, s), LEAF, 0.35, seed)
			p.ball(c + Vector3(s * 0.5, s * 0.8, 0.02), Vector3(s, s, s) * 0.7, LEAF_LT, 0.35, seed + 9)
			if stage >= 3:
				for k in 4:
					var a := k * 1.6 + seed
					p.ball(c + Vector3(cos(a) * s * 0.8, s * (0.7 + 0.25 * k), s * 0.75), Vector3.ONE * 0.045, STEM if stage == 3 else RED)
		_:
			var s: float = [0.0, 0.0, 0.1, 0.15, 0.19][stage]
			for k in 6:
				var a := k * 1.05
				p.ball(c + Vector3(cos(a) * s * 0.75, s * 0.25, sin(a) * s * 0.6), Vector3(s * 0.7, s * 0.3, s * 0.6), LEAF_LT if k % 2 else LEAF)
			if stage >= 3:
				p.ball(c + Vector3(0, s * 0.55, 0), Vector3.ONE * s * 0.7, Color("9fd27a") if stage == 3 else Color("c8e8a0"))

static func fence(b: MeshBatch, at: Vector3, w: float, d: float) -> void:
	var p := Pen.new(b, at)
	for y in [0.2, 0.45]:
		p.box(Vector3(-w * 0.5, y, -0.03), Vector3(w * 0.5, y + 0.06, 0.03), WHITE)
	var n := maxi(2, int(round(w * 4)))
	for i in n:
		var x := -w * 0.5 + (i + 0.5) * w / n
		p.box(Vector3(x - 0.05, 0, -0.04), Vector3(x + 0.05, 0.6, 0.0), WHITE)
		p.cone(Vector3(x, 0.6, -0.02), 0.06, 0.08, WHITE)

static func coop(b: MeshBatch, at: Vector3, w: float, d: float) -> void:
	var p := Pen.new(b, at)
	var hw := w * 0.42
	var hd := d * 0.34
	p.box(Vector3(-hw - 0.05, 0, -hd - 0.05), Vector3(hw + 0.05, 0.12, hd + 0.05), Color("b9ad99"))
	p.box(Vector3(-hw, 0.12, -hd), Vector3(hw, 1.35, hd), WHITE)
	for i in 8:                                                               # board lines
		var y := 0.25 + i * 0.14
		p.box(Vector3(-hw - 0.005, y, hd), Vector3(hw + 0.005, y + 0.015, hd + 0.01), Color("e3d3bb"))
	var rise := 0.75
	var run := hd + 0.2
	var slope := sqrt(rise * rise + run * run)
	var ang := atan2(rise, run)
	p.tilted(Vector3(0, 1.35 + rise * 0.5, run * 0.5), Vector3(hw * 2 + 0.3, 0.08, slope), ang, ROOF)
	p.tilted(Vector3(0, 1.35 + rise * 0.5, -run * 0.5), Vector3(hw * 2 + 0.3, 0.08, slope), -ang, ROOF)
	p.box(Vector3(-hw - 0.15, 1.35 + rise - 0.03, -0.05), Vector3(hw + 0.15, 1.35 + rise + 0.05, 0.05), WHITE)
	p.box(Vector3(-0.32, 0.12, hd), Vector3(0.32, 1.0, hd + 0.04), WOOD)                     # door
	p.tilted(Vector3(0, 0.08, hd + 0.35), Vector3(0.5, 0.04, 0.75), 0.18, WOOD_LT)            # ramp
	p.ball(Vector3(hw * 0.6, 0.95, hd + 0.01), Vector3(0.19, 0.19, 0.03), WHITE)              # round window
	p.ball(Vector3(hw * 0.6, 0.95, hd + 0.025), Vector3(0.14, 0.14, 0.02), GLASS)
	for k in 2:                                                                               # hens
		var hx := -hw * 0.7 + k * 0.4
		p.ball(Vector3(hx, 0.14, hd + 0.5), Vector3(0.12, 0.1, 0.14), WHITE)
		p.ball(Vector3(hx, 0.26, hd + 0.58), Vector3(0.06, 0.06, 0.06), WHITE)
		p.ball(Vector3(hx, 0.33, hd + 0.58), Vector3(0.025, 0.03, 0.04), RED)
		p.cone(Vector3(hx, 0.24, hd + 0.64), 0.015, 0.04, GOLD)

# ------------------------------------------------------------------ nature
static func tree(b: MeshBatch, at: Vector3, seed: int, small: bool) -> void:
	var p := Pen.new(b, at, seed % 4)
	var s := 0.65 if small else 1.0
	p.cyl(Vector3.ZERO, 0.11 * s, 1.0 * s, TRUNK)
	p.rod(Vector3(0, 0.7 * s, 0), Vector3(-0.3, 1.15, 0.05) * s, 0.05 * s, TRUNK)
	var greens := [LEAF, LEAF_LT, LEAF_DK, LEAF]
	var clumps := [[0.0, 1.55, 0.0, 0.62], [-0.38, 1.3, 0.1, 0.45], [0.4, 1.3, -0.05, 0.45], [0.05, 1.95, 0.05, 0.42], [0.0, 1.25, 0.35, 0.4]]
	for i in clumps.size():
		var c: Array = clumps[i]
		p.ball(Vector3(c[0], c[1], c[2]) * s, Vector3.ONE * float(c[3]) * s, greens[(i + seed) % 4].lerp(Color("a6d06a"), 0.08 * (seed % 3)), 0.25, seed * 7 + i)

static func palm(b: MeshBatch, at: Vector3, seed: int) -> void:
	var p := Pen.new(b, at, seed % 4)
	var pts: Array[Vector3] = []
	for i in 6:
		var t := i / 5.0
		pts.append(Vector3(sin(t * 1.4) * 0.45, t * 2.2, 0.0))
	for i in 5:
		p.rod(pts[i], pts[i + 1], 0.09 - i * 0.008, Color("a07850") if i % 2 == 0 else Color("8a6644"))
	var top := pts[5]
	for k in 7:                                                               # fronds: drooping leaves made of three slabs each
		var a := k * TAU / 7.0 + seed
		var dir := Vector3(cos(a), 0, sin(a))
		var prev := top
		for j in 3:
			var nxt := top + dir * (0.35 * (j + 1)) + Vector3(0, 0.12 - 0.14 * j * j * 0.5, 0)
			p.rod(prev, nxt, 0.07 - j * 0.015, LEAF if j % 2 == 0 else LEAF_LT)
			prev = nxt
	for k in 3:
		p.ball(top + Vector3(cos(k * 2.1) * 0.12, -0.1, sin(k * 2.1) * 0.12), Vector3.ONE * 0.08, Color("6b4a2c"))

static func bush(b: MeshBatch, at: Vector3, seed: int) -> void:
	var p := Pen.new(b, at)
	p.ball(Vector3(0, 0.28, 0), Vector3(0.38, 0.3, 0.34), LEAF, 0.3, seed)
	p.ball(Vector3(-0.25, 0.2, 0.1), Vector3(0.25, 0.2, 0.24), LEAF_LT, 0.3, seed + 1)
	p.ball(Vector3(0.25, 0.2, 0.05), Vector3(0.24, 0.2, 0.24), LEAF_DK, 0.3, seed + 2)
	for k in 6:
		var a := k * 1.1 + seed
		p.ball(Vector3(cos(a) * 0.3, 0.3 + 0.08 * (k % 3), 0.25), Vector3.ONE * 0.035, Color("c8343a"))

static func rock(b: MeshBatch, at: Vector3, seed: int) -> void:
	var p := Pen.new(b, at, seed % 4)
	p.ball(Vector3(0, 0.12, 0), Vector3(0.38, 0.22, 0.32), ROCK, 0.35, seed)
	p.ball(Vector3(-0.28, 0.06, 0.15), Vector3(0.18, 0.11, 0.16), ROCK.darkened(0.15), 0.35, seed + 3)

# ------------------------------------------------------------------ seaside bits
static func umbrella(b: MeshBatch, at: Vector3, col: Color) -> void:
	var p := Pen.new(b, at)
	p.cyl(Vector3.ZERO, 0.03, 1.6, WHITE)
	p.cone(Vector3(0, 1.35, 0), 0.9, 0.35, col)
	p.cone(Vector3(0, 1.351, 0), 0.6, 0.26, WHITE)

static func lounger(b: MeshBatch, at: Vector3, col: Color) -> void:
	var p := Pen.new(b, at)
	p.box(Vector3(-0.28, 0.15, -0.45), Vector3(0.28, 0.2, 0.55), WOOD_LT)
	p.tilted(Vector3(0, 0.35, -0.55), Vector3(0.56, 0.05, 0.5), 1.0, WOOD_LT)
	p.box(Vector3(-0.25, 0.2, -0.4), Vector3(0.25, 0.24, 0.5), col)
	for sx in [-0.24, 0.24]:
		for sz in [-0.35, 0.45]:
			p.box(Vector3(sx - 0.03, 0, sz - 0.03), Vector3(sx + 0.03, 0.15, sz + 0.03), WOOD_DK)

static func pier(b: MeshBatch, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	b.box(Vector3(x0, y - 0.08, z0), Vector3(x1, y, z1), WOOD)
	var n := int((z1 - z0) / 0.3)
	for i in n:                                                               # plank gaps
		var z := z0 + i * 0.3
		b.box(Vector3(x0, y - 0.005, z), Vector3(x1, y + 0.005, z + 0.02), WOOD_DK)
	for z in [z0 + 0.3, (z0 + z1) * 0.5, z1 - 0.15]:
		for x in [x0 + 0.08, x1 - 0.08]:
			b.cyl(Vector3(x, y - 1.2, z), 0.07, 1.25, WOOD_DK)

static func boat(b: MeshBatch, at: Vector3) -> void:
	var p := Pen.new(b, at, 1)
	p.ball(Vector3(0, 0.05, 0), Vector3(0.55, 0.22, 1.3), WHITE)
	p.ball(Vector3(0, 0.12, 0), Vector3(0.45, 0.12, 1.15), WOOD)
	p.box(Vector3(-0.5, 0.0, -0.15), Vector3(0.5, 0.12, 0.15), RED)
	p.cyl(Vector3(0, 0.1, 0.1), 0.03, 1.6, WOOD_DK)
	p.tilted(Vector3(0, 1.0, 0.45), Vector3(0.02, 1.1, 0.7), 0.0, WHITE)
