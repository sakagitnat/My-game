class_name Island
extends RefCounted

# The one island everything sits on. Its outline is an organic coast (a smooth field, see BLOBS) laid over a
# square grid; it is cut into land blocks (parcels) of WorldGrid.PARCEL cells and every block carries a label
# saying what the place is for. Labels decide which blocks the player can buy,
# which items can be placed where, and how many trees and rocks lie around. The renderer may read labels
# (label_of_cell / label_of_parcel) to paint places; it must never change them.
#
# Reading the map: rows go down the screen toward the bottom-left edge (y), columns toward the bottom-right (x),
# so the top corner of the diamond is the top-left character.
#
#   W forest reserve        X open land kept for future updates   L lighthouse
#   F farm (player)         R restaurant (player)                  P plaza and community hall
#   G grocery               C clothes shop                         J carpenter
#   M clinic                S school                               H islander houses
#   h house a little apart  K harbor                               O old resort (starts run down)
#   T paths and town green  ~ open sea around the island  A anything goes (tests only)

const MAP: Array[String] = [
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

# name: strings key. sale: the player may buy these blocks. area: which placeable group may stand here ("" none).
# density: scale for obstacle scatter (1 is the usual amount); forest: how strongly the forest noise adds trees.
const LABELS := {
	"W": {"name": "AREA_FOREST", "sale": false, "area": "", "density": 3.0, "forest": 0.85},
	"X": {"name": "AREA_OPEN", "sale": false, "area": "", "density": 1.5, "forest": 0.30},
	"L": {"name": "AREA_LIGHTHOUSE", "sale": false, "area": "", "density": 0.4, "forest": 0.0},
	"F": {"name": "AREA_FARM", "sale": true, "area": "farm", "density": 1.0, "forest": 0.30},
	"R": {"name": "AREA_RESTAURANT", "sale": true, "area": "restaurant", "density": 1.0, "forest": 0.30},
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
	"~": {"name": "AREA_SEA", "sale": false, "area": "", "density": 0.0, "forest": 0.0},
	"A": {"name": "AREA_ANY", "sale": true, "area": "any", "density": 1.0, "forest": 0.30},
}

# The coast: land is where the sum of these soft bumps (x, y in blocks, sigma in blocks, weight) is above
# COAST_LEVEL. The map has one block of open sea all around. A negative weight cuts a bay. Noise on top makes the shoreline uneven.
const BLOBS := [
	[5.4, 5.4, 2.6, 1.0],    # main body
	[2.7, 2.6, 1.4, 0.55],   # forest in the north-west
	[2.3, 6.2, 1.5, 0.5],    # farm shore in the west
	[8.6, 5.4, 1.1, 0.4],    # east side
	[7.5, 3.8, 1.0, 0.4],    # neck to the lighthouse
	[9.0, 2.0, 1.0, 0.7],    # lighthouse headland
	[8.4, 8.4, 1.2, 0.55],   # old resort beach
	[5.4, 9.3, 1.3, 0.45],   # harbour shore
	[5.6, 10.9, 0.9, -0.5],  # harbour cove
]
const COAST_LEVEL := 0.5
const COAST_NOISE := 0.25

var rows: Array[String]
var starts: Array[Vector2i]
var farm_start: Vector2i
var restaurant_start: Vector2i
var organic := true
var cells := Vector2i.ZERO          # grid size in cells
var field: PackedFloat32Array       # per cell corner (cells + 1 in each direction): above 0 is land
var dist: PackedFloat32Array        # per cell corner: steps to the nearest water corner (0 in the water)
var _parcel_sale: Dictionary = {}

func _init(map_rows: Array[String], start_parcels: Array[Vector2i], with_coast: bool = true) -> void:
	rows = map_rows
	starts = start_parcels
	organic = with_coast
	cells = parcel_count() * WorldGrid.PARCEL
	_build_field()
	_build_distance()

# The real island: the player begins with one restaurant block and the farm block beside it.
static func standard() -> Island:
	var i := Island.new(MAP, [Vector2i(3, 5), Vector2i(2, 5)])
	i.restaurant_start = Vector2i(3, 5)
	i.farm_start = Vector2i(2, 5)
	return i

# Same size as the island but every block is for sale and takes every item (used by the tests).
static func sandbox() -> Island:
	var map: Array[String] = []
	for y in MAP.size():
		map.append("A".repeat(MAP[0].length()))
	var i := Island.new(map, [Vector2i(2, 2)], false)
	i.restaurant_start = Vector2i(2, 2)
	i.farm_start = Vector2i(2, 2)
	return i

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
			if organic:
				# Cell corner (vx, vy) sits at (vx - 0.5, vy - 0.5) in cell coordinates.
				var px := (vx - 0.5) / WorldGrid.PARCEL
				var py := (vy - 0.5) / WorldGrid.PARCEL
				var sum := 0.0
				for b in BLOBS:
					var dx: float = px - b[0]
					var dy: float = py - b[1]
					sum += float(b[3]) * exp(-(dx * dx + dy * dy) / (2.0 * float(b[2]) * float(b[2])))
				sum += COAST_NOISE * (Noise2D.value(vx * 0.14, vy * 0.14, 41) - 0.5) + COAST_NOISE * 0.45 * (Noise2D.value(vx * 0.42, vy * 0.42, 43) - 0.5)
				v = sum - COAST_LEVEL
				if vx < 3 or vy < 3 or vx > cells.x - 3 or vy > cells.y - 3:
					v = minf(v, -0.05)
			else:
				v = float(mini(mini(vx, vy), mini(cells.x - vx, cells.y - vy)))
			field[vy * vs.x + vx] = v

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
	if not organic:
		return true
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

# Whole cells between this cell and the water (0 on the outermost ring of a square map).
func edge_distance(c: Vector2i) -> int:
	if not has_land(c):
		return -1
	var d := 9999.0
	for k in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		d = minf(d, vertex_distance(c.x + k.x, c.y + k.y))
	return floori(d)

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
