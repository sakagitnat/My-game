class_name SceneLayout
extends RefCounted

# What a scene's land looks like: its size, which land blocks (parcels of WorldGrid.PARCEL cells) are for sale,
# which kind of item each block takes, where the water is, and for the restaurant its starting building and road.
# The renderer may read all of this (label_of_cell, is_road, shell, coast_segments ...) but never changes it.
#
# Scenes: restaurant (a seaside plot with a country road in front), farm, and the whole-island overview
# (art only, see docs/SCENES.md). tests use sandbox().
#
# Reading a map: rows go down the screen toward the bottom-left edge (y), columns toward the bottom-right (x),
# so the top corner of the diamond is the top-left character.
#
#   ~ open sea            B seaside terrace (restaurant land)     r garden land (restaurant land)
#   W woods (the edge of the restaurant scene, also the forest reserve of the overview)
#   R the starting shop   = country road                          F farm land
#   A anything goes (tests only)
#   overview only: W forest reserve, X open land kept for later, L lighthouse, P plaza, S school, M clinic,
#   C clothes shop, J carpenter, G grocery, H houses, h a house apart,
#   K harbor, O old resort, T paths and town green

const RESTAURANT_MAP: Array[String] = [
	"~~~~~~~~",
	"~~BBBB~~",
	"WrrRRrrW",
	"WrrRRrrW",
	"========",
	"WWWWWWWW",
]
const FARM_MAP: Array[String] = [
	"FFFFF",
	"FFFFF",
	"FFFFF",
	"FFFFF",
	"FFFFF",
]
const OVERVIEW_MAP: Array[String] = [
	"~~~~~~~~~~~",
	"~WWWWXXXLL~",
	"~WWWhXXXLL~",
	"~WWWXXSXHH~",
	"~FFRRGPCHH~",
	"~FFRRMPJHH~",
	"~FFFXTTTHX~",
	"~FFFXTTTXO~",
	"~XXFKKKTOO~",
	"~XXXKKKTOO~",
	"~~~~~~~~~~~",
]

# name: strings key. sale: the player may buy these blocks. area: which placeable group may stand here
# ("" none, "any" all). density: scale for obstacle scatter (1 is the usual amount); forest: how strongly the
# forest noise adds trees.
const LABELS := {
	"~": {"name": "AREA_SEA", "sale": false, "area": "", "density": 0.0, "forest": 0.0},
	"B": {"name": "AREA_TERRACE", "sale": true, "area": "restaurant", "density": 0.8, "forest": 0.0},
	"r": {"name": "AREA_GARDEN", "sale": true, "area": "restaurant", "density": 2.2, "forest": 0.25},
	"R": {"name": "AREA_SHOP", "sale": false, "area": "restaurant", "density": 0.0, "forest": 0.0},
	"=": {"name": "AREA_ROAD", "sale": false, "area": "", "density": 0.0, "forest": 0.0},
	"F": {"name": "AREA_FARM", "sale": true, "area": "farm", "density": 1.0, "forest": 0.30},
	"A": {"name": "AREA_ANY", "sale": true, "area": "any", "density": 1.0, "forest": 0.30},
	"W": {"name": "AREA_FOREST", "sale": false, "area": "", "density": 3.0, "forest": 0.85},
	"X": {"name": "AREA_OPEN", "sale": false, "area": "", "density": 1.5, "forest": 0.30},
	"L": {"name": "AREA_LIGHTHOUSE", "sale": false, "area": "", "density": 0.4, "forest": 0.0},
	"P": {"name": "AREA_PLAZA", "sale": false, "area": "", "density": 0.0, "forest": 0.0},
	"G": {"name": "AREA_GROCERY", "sale": false, "area": "", "density": 0.3, "forest": 0.0},
	"C": {"name": "AREA_CLOTHES", "sale": false, "area": "", "density": 0.3, "forest": 0.0},
	"J": {"name": "AREA_CARPENTER", "sale": false, "area": "", "density": 0.3, "forest": 0.0},
	"M": {"name": "AREA_CLINIC", "sale": false, "area": "", "density": 0.3, "forest": 0.0},
	"S": {"name": "AREA_SCHOOL", "sale": false, "area": "", "density": 0.3, "forest": 0.0},
	"H": {"name": "AREA_HOUSES", "sale": false, "area": "", "density": 0.4, "forest": 0.0},
	"h": {"name": "AREA_HOUSE", "sale": false, "area": "", "density": 0.8, "forest": 0.2},
	"K": {"name": "AREA_HARBOR", "sale": false, "area": "", "density": 0.2, "forest": 0.0},
	"O": {"name": "AREA_RESORT", "sale": false, "area": "", "density": 0.8, "forest": 0.0},
	"T": {"name": "AREA_TOWN", "sale": false, "area": "", "density": 0.0, "forest": 0.0},
}

# The overview coast: land is where the sum of these soft bumps (x, y in blocks, sigma in blocks, weight) is above
# COAST_LEVEL; a negative weight cuts a bay. One block of open sea all around. Noise makes the shore uneven.
const BLOBS := [
	[5.4, 5.4, 2.6, 1.0],
	[2.7, 2.6, 1.4, 0.55],
	[2.3, 6.2, 1.5, 0.5],
	[8.6, 5.4, 1.1, 0.4],
	[7.5, 3.8, 1.0, 0.4],
	[9.0, 2.0, 1.0, 0.7],
	[8.4, 8.4, 1.2, 0.55],
	[5.4, 9.3, 1.3, 0.45],
	[5.6, 10.9, 0.9, -0.5],
]
const COAST_LEVEL := 0.5
const COAST_NOISE := 0.25

var id := ""
var kind := "square"                 # "bay" (restaurant), "square" (a plot with a beach all round), "island" (overview)
var rows: Array[String]
var starts: Array[Vector2i]
var shell := Rect2i()                # the starting building, in cells (empty when the scene has none)
var door_cells: Array[Vector2i] = [] # cells in the front wall where the door is
var road := Rect2i()                 # cells of the dirt road (the rest of the road block is grass verge)
var pavement := Rect2i()             # paved strip in front of the door
var cells := Vector2i.ZERO           # size in cells
var field: PackedFloat32Array        # per cell corner (cells + 1 in each direction): above 0 is land
var dist: PackedFloat32Array         # per cell corner: steps to the nearest water corner (0 in the water)
var _parcel_sale: Dictionary = {}

func _init(scene_id: String, scene_kind: String, map_rows: Array[String], start_parcels: Array[Vector2i]) -> void:
	id = scene_id
	kind = scene_kind
	rows = map_rows
	starts = start_parcels
	cells = parcel_count() * WorldGrid.PARCEL
	_build_field()
	_build_distance()

static func restaurant() -> SceneLayout:
	var s := SceneLayout.new("restaurant", "bay", RESTAURANT_MAP, [Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3), Vector2i(4, 3)])
	var p := WorldGrid.PARCEL
	s.shell = Rect2i(Vector2i(3, 2) * p, Vector2i(2, 2) * p)
	s.door_cells = [Vector2i(23, 23), Vector2i(24, 23)]
	s.road = Rect2i(0, 25, 48, 4)
	s.pavement = Rect2i(17, 24, 14, 1)
	return s

static func farm() -> SceneLayout:
	return SceneLayout.new("farm", "square", FARM_MAP, [Vector2i(2, 2)])

static func overview() -> SceneLayout:
	return SceneLayout.new("overview", "island", OVERVIEW_MAP, [Vector2i(3, 5), Vector2i(2, 5)])

# Every block is for sale and takes every item (used by the tests): 30 x 30 cells, start block (2, 2).
static func sandbox() -> SceneLayout:
	var map: Array[String] = []
	for y in range(5):
		map.append("AAAAA")
	return SceneLayout.new("sandbox", "square", map, [Vector2i(2, 2)])

func parcel_count() -> Vector2i:
	return Vector2i(rows[0].length(), rows.size())

func label_of_parcel(p: Vector2i) -> String:
	if p.y < 0 or p.y >= rows.size() or p.x < 0 or p.x >= rows[p.y].length():
		return ""
	return rows[p.y][p.x]

func label_of_cell(c: Vector2i) -> String:
	return label_of_parcel(WorldGrid.parcel_of(c))

func info_of_parcel(p: Vector2i) -> Dictionary:
	return LABELS.get(label_of_parcel(p), {})

func is_road(c: Vector2i) -> bool:
	return label_of_cell(c) == "="

# Cell in the middle of the starting building or, without one, of the first starting block.
func start_cell() -> Vector2i:
	if shell.has_area():
		return shell.position + shell.size / 2
	return starts[0] * WorldGrid.PARCEL + Vector2i.ONE * (WorldGrid.PARCEL / 2)

# True for the blocks the starting building stands on.
func is_shell_parcel(p: Vector2i) -> bool:
	return shell.has_area() and shell.has_point(p * WorldGrid.PARCEL)

# A block is for sale when its label says so and enough of it is dry land (a sign must stand on land).
func for_sale(p: Vector2i) -> bool:
	if not bool(info_of_parcel(p).get("sale", false)):
		return false
	if not _parcel_sale.has(p):
		var n := 0
		for y in range(WorldGrid.PARCEL):
			for x in range(WorldGrid.PARCEL):
				if is_solid(p * WorldGrid.PARCEL + Vector2i(x, y)):
					n += 1
		_parcel_sale[p] = n >= 12 and is_solid(p * WorldGrid.PARCEL + Vector2i.ONE * (WorldGrid.PARCEL / 2))
	return _parcel_sale[p]

# Whether an item of placement group `area` ("restaurant", "farm") may cover cell `c`.
func allows(area: String, c: Vector2i) -> bool:
	var a := str(info_of_parcel(WorldGrid.parcel_of(c)).get("area", ""))
	return a == "any" or (a != "" and a == area)

# All blocks the player may ever buy.
func sale_parcels() -> Dictionary:
	var out := {}
	for y in rows.size():
		for x in rows[y].length():
			if for_sale(Vector2i(x, y)):
				out[Vector2i(x, y)] = true
	return out

# ---------------------------------------------------------------- coast

func _vertex_size() -> Vector2i:
	return cells + Vector2i.ONE

func _build_field() -> void:
	var vs := _vertex_size()
	field = PackedFloat32Array()
	field.resize(vs.x * vs.y)
	for vy in range(vs.y):
		for vx in range(vs.x):
			var v := 1.0
			match kind:
				"island": v = _island_field(vx, vy)
				"bay": v = _bay_field(vx, vy)
				_: v = float(mini(mini(vx, vy), mini(cells.x - vx, cells.y - vy)))
			field[vy * vs.x + vx] = v

# Corner (vx, vy) sits at (vx - 0.5, vy - 0.5) in cell coordinates.
func _island_field(vx: int, vy: int) -> float:
	var px := (vx - 0.5) / WorldGrid.PARCEL
	var py := (vy - 0.5) / WorldGrid.PARCEL
	var sum := 0.0
	for b in BLOBS:
		var dx: float = px - b[0]
		var dy: float = py - b[1]
		sum += float(b[3]) * exp(-(dx * dx + dy * dy) / (2.0 * float(b[2]) * float(b[2])))
	sum += COAST_NOISE * (Noise2D.value(vx * 0.14, vy * 0.14, 41) - 0.5) + COAST_NOISE * 0.45 * (Noise2D.value(vx * 0.42, vy * 0.42, 43) - 0.5)
	var v := sum - COAST_LEVEL
	if vx < 3 or vy < 3 or vx > cells.x - 3 or vy > cells.y - 3:
		v = minf(v, -0.05)
	return v

# Sea along the back (top-right edge on screen) curving round the two ends, land reaching the other edges:
# the front edge carries the road, which runs off both sides of the scene.
func _bay_field(vx: int, vy: int) -> float:
	var t := (vx - cells.x * 0.5) / (cells.x * 0.5)
	var coast_y := 7.0 + 6.0 * pow(absf(t), 3.0) + 1.6 * (Noise2D.value(vx * 0.16, 3.0, 51) - 0.5) + 0.6 * (Noise2D.value(vx * 0.5, 7.0, 53) - 0.5)
	var v := vy - 0.5 - coast_y
	if vy < 3:
		v = minf(v, -0.05)
	return v

func vertex_field(vx: int, vy: int) -> float:
	var vs := _vertex_size()
	if vx < 0 or vy < 0 or vx >= vs.x or vy >= vs.y:
		return -1.0
	return field[vy * vs.x + vx]

# Chamfer distance, in cells, from a corner to the nearest water corner.
func _build_distance() -> void:
	var vs := _vertex_size()
	dist = PackedFloat32Array()
	dist.resize(vs.x * vs.y)
	for i in dist.size():
		dist[i] = 0.0 if field[i] <= 0.0 else 9999.0
	for pass_i in range(2):
		var ys := range(vs.y) if pass_i == 0 else range(vs.y - 1, -1, -1)
		var xs := range(vs.x) if pass_i == 0 else range(vs.x - 1, -1, -1)
		var step := 1 if pass_i == 0 else -1
		for y in ys:
			for x in xs:
				var best: float = dist[y * vs.x + x]
				for off in [Vector2i(-step, 0), Vector2i(0, -step), Vector2i(-step, -step), Vector2i(step, -step)]:
					var nx: int = x + off.x
					var ny: int = y + off.y
					if nx < 0 or ny < 0 or nx >= vs.x or ny >= vs.y:
						continue
					var w := 1.0 if off.x == 0 or off.y == 0 else 1.4142
					best = minf(best, dist[ny * vs.x + nx] + w)
				dist[y * vs.x + x] = best

func vertex_distance(vx: int, vy: int) -> float:
	var vs := _vertex_size()
	if vx < 0 or vy < 0 or vx >= vs.x or vy >= vs.y:
		return 0.0
	return dist[vy * vs.x + vx]

func _corners_of(c: Vector2i) -> Array[float]:
	return [vertex_field(c.x, c.y), vertex_field(c.x + 1, c.y), vertex_field(c.x + 1, c.y + 1), vertex_field(c.x, c.y + 1)]

# True when the whole cell is dry land (all four corners): the only cells things may stand on.
func is_solid(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= cells.x or c.y >= cells.y:
		return false
	if kind == "square":
		return true  # a square plot is land to its last cell; the beach is only painted
	for f in _corners_of(c):
		if f <= 0.0:
			return false
	return true

# True when any part of the cell is land (it may be drawn as a partial cell on the shore).
func has_land(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= cells.x or c.y >= cells.y:
		return false
	for f in _corners_of(c):
		if f > 0.0:
			return true
	return false

# Whole cells between this cell and the water (0 on the outermost ring of a square plot, -1 in the water).
func edge_distance(c: Vector2i) -> int:
	if not has_land(c):
		return -1
	var d := 9999.0
	for k in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		d = minf(d, vertex_distance(c.x + k.x, c.y + k.y))
	return floori(minf(d, 99.0))

# Shoreline pieces for the renderer: [from, to, normal toward the water], all in float cell coordinates.
func coast_segments() -> Array:
	var out: Array = []
	for y in range(cells.y):
		for x in range(cells.x):
			var f := _corners_of(Vector2i(x, y))
			var pos := 0
			for v in f:
				if v > 0.0:
					pos += 1
			if pos == 0 or pos == 4:
				continue
			# corner order: (0,0) (1,0) (1,1) (0,1)
			var pts: Array[Vector2] = []
			var origin := Vector2(x, y) - Vector2(0.5, 0.5)
			var corner: Array[Vector2] = [origin, origin + Vector2(1, 0), origin + Vector2(1, 1), origin + Vector2(0, 1)]
			for i in range(4):
				var a: float = f[i]
				var b: float = f[(i + 1) % 4]
				if (a > 0.0) != (b > 0.0):
					pts.append(corner[i].lerp(corner[(i + 1) % 4], a / (a - b)))
			var grad := Vector2((f[1] + f[2] - f[0] - f[3]) * 0.5, (f[3] + f[2] - f[0] - f[1]) * 0.5)
			var n := -grad.normalized() if grad.length() > 0.0001 else Vector2.ZERO
			for k in range(0, pts.size() - 1, 2):
				out.append([pts[k], pts[k + 1], n])
	return out
