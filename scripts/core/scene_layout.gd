class_name SceneLayout
extends RefCounted

# One scene's map, as designed by the owner: tiles (ground kinds), walls on cell edges, the trees and rocks
# standing about, pre-placed objects, and which land blocks (parcels of WorldGrid.PARCEL cells) are owned from
# the start or for sale. It is plain data (see to_dict / from_dict, data/maps/*.json and MapStore) so the map
# editor can change it and the owner can send a finished map back as text.
#
# The renderer may read everything here (tile_at, wall_at, is_solid, coast_segments ...) but never changes it.
# Coordinates: cell (x, y); x runs toward the bottom-right of the screen, y toward the bottom-left.

enum Tile { GRASS, SAND, WATER, ROAD, PAVEMENT, FLOOR, DIRT }
const TILE_CODES := {"g": Tile.GRASS, "s": Tile.SAND, "w": Tile.WATER, "r": Tile.ROAD, "p": Tile.PAVEMENT, "f": Tile.FLOOR, "d": Tile.DIRT}
const TILE_CHARS := "gswrpfd"
# Wall kinds. edge "n" is the north face of a cell (between y-1 and y), "w" its west face (between x-1 and x).
const WALL_KINDS := ["wall", "window", "door", "low"]
const SAVE_VERSION := 1

var id := ""
var area := "restaurant"             # which placeable group this scene takes: "restaurant", "farm" or "any"
var cells := Vector2i.ZERO
var tiles := PackedByteArray()       # cells.x * cells.y Tile values
var walls: Dictionary = {}           # "x,y,e" -> kind
var obstacles: Array = []            # [x, y, kind]
var objects: Array = []              # [x, y, placeable id] (origin cell), free and ready at the start
var parcels: Array[String] = []      # rows of: '.' locked, 'B' for sale, 'S' owned from the start
var exits: Array = []                # reserved for scene changes
var scatter := false                 # tests: fill the free land with random trees at the start
var field: PackedFloat32Array        # per cell corner (cells + 1 each way): above 0 is land
var dist: PackedFloat32Array         # per cell corner: steps to the nearest water corner
var starts: Array[Vector2i] = []
var _parcel_sale: Dictionary = {}

# ---------------------------------------------------------------- building

static func blank(scene_id: String, scene_area: String, size: Vector2i) -> SceneLayout:
	var s := SceneLayout.new()
	s.id = scene_id
	s.area = scene_area
	s.cells = size
	s.tiles.resize(size.x * size.y)
	s.tiles.fill(Tile.GRASS)
	var pc := size / WorldGrid.PARCEL
	for y in range(pc.y):
		s.parcels.append(".".repeat(pc.x))
	s.rebuild()
	return s

# Tests: 30 x 30 cells of open grass, every block for sale, block (2, 2) owned, takes every item.
static func sandbox() -> SceneLayout:
	var s := SceneLayout.blank("sandbox", "any", Vector2i(30, 30))
	for y in range(5):
		s.parcels[y] = "BBBBB" if y != 2 else "BBSBB"
	s.scatter = true
	s.rebuild()
	return s

static func from_dict(d: Dictionary) -> SceneLayout:
	var size := Vector2i(int(d.get("size", [30, 30])[0]), int(d.get("size", [30, 30])[1]))
	var s := SceneLayout.blank(str(d.get("id", "")), str(d.get("area", "any")), size)
	var rows: Array = d.get("tiles", [])
	for y in range(mini(rows.size(), size.y)):
		var row := str(rows[y])
		for x in range(mini(row.length(), size.x)):
			s.tiles[y * size.x + x] = TILE_CODES.get(row[x], Tile.GRASS)
	for w in d.get("walls", []):
		if w is Array and w.size() >= 4:
			s.set_wall(Vector2i(int(w[0]), int(w[1])), str(w[2]), str(w[3]))
	for o in d.get("obstacles", []):
		if o is Array and o.size() >= 3 and Catalog.OBSTACLES.has(str(o[2])):
			s.obstacles.append([int(o[0]), int(o[1]), str(o[2])])
	for o in d.get("objects", []):
		if o is Array and o.size() >= 3 and Catalog.PLACEABLES.has(str(o[2])):
			s.objects.append([int(o[0]), int(o[1]), str(o[2])])
	var prows: Array = d.get("parcels", [])
	var pc := size / WorldGrid.PARCEL
	s.parcels.clear()
	for y in range(pc.y):
		var row := str(prows[y]) if y < prows.size() else ""
		s.parcels.append((row + ".".repeat(pc.x)).left(pc.x))
	s.exits = d.get("exits", []).duplicate()
	s.rebuild()
	return s

func to_dict() -> Dictionary:
	var rows: Array = []
	for y in range(cells.y):
		var row := ""
		for x in range(cells.x):
			row += TILE_CHARS[tiles[y * cells.x + x]]
		rows.append(row)
	var wl: Array = []
	for key in walls:
		var p: PackedStringArray = str(key).split(",")
		wl.append([int(p[0]), int(p[1]), p[2], walls[key]])
	wl.sort_custom(func(a: Array, b: Array) -> bool: return [a[1], a[0], a[2]] < [b[1], b[0], b[2]])
	var prows: Array = []
	for r in parcels:
		prows.append(r)
	return {"version": SAVE_VERSION, "id": id, "area": area, "size": [cells.x, cells.y], "tiles": rows, "walls": wl,
		"obstacles": obstacles.duplicate(true), "objects": objects.duplicate(true), "parcels": prows, "exits": exits.duplicate(true)}

# Takes over everything from another layout (undo / redo restore a saved copy into the same object).
func copy_from(other: SceneLayout) -> void:
	id = other.id
	area = other.area
	cells = other.cells
	tiles = other.tiles.duplicate()
	walls = other.walls.duplicate()
	obstacles = other.obstacles.duplicate(true)
	objects = other.objects.duplicate(true)
	parcels = other.parcels.duplicate()
	exits = other.exits.duplicate(true)
	scatter = other.scatter
	rebuild()

# New size in land blocks; the top-left part is kept, new ground is grass, what falls outside is dropped.
func resize(block_count: Vector2i) -> void:
	var new_cells := block_count * WorldGrid.PARCEL
	var new_tiles := PackedByteArray()
	new_tiles.resize(new_cells.x * new_cells.y)
	new_tiles.fill(Tile.GRASS)
	for y in range(mini(cells.y, new_cells.y)):
		for x in range(mini(cells.x, new_cells.x)):
			new_tiles[y * new_cells.x + x] = tiles[y * cells.x + x]
	var old_cells := cells
	cells = new_cells
	tiles = new_tiles
	for key in walls.keys():
		var p: PackedStringArray = str(key).split(",")
		if not edge_in_bounds(Vector2i(int(p[0]), int(p[1])), p[2]):
			walls.erase(key)
	obstacles = obstacles.filter(func(o: Array) -> bool: return in_bounds(Vector2i(o[0], o[1])))
	objects = objects.filter(func(o: Array) -> bool: return in_bounds(Iso.cell_of_unit(Vector2i(o[0], o[1]))))
	var new_rows: Array[String] = []
	for y in range(block_count.y):
		var row := parcels[y] if y < parcels.size() else ""
		new_rows.append((row + ".".repeat(block_count.x)).left(block_count.x))
	parcels = new_rows
	if old_cells != new_cells:
		rebuild()

# Drops trees, rocks and objects that no longer stand on ground they may stand on (after painting over them).
func prune_props() -> void:
	obstacles = obstacles.filter(func(o: Array) -> bool:
		var t := tile_at(Vector2i(o[0], o[1]))
		return t == Tile.GRASS or t == Tile.SAND or t == Tile.DIRT)
	objects = objects.filter(func(o: Array) -> bool:
		var sz: Vector2i = Catalog.size_of(str(o[2]))
		for y in range(sz.y):
			for x in range(sz.x):
				var t := tile_at(Iso.cell_of_unit(Vector2i(o[0] + x, o[1] + y)))
				if t == Tile.WATER or t == Tile.ROAD:
					return false
		return true)

# Recomputes everything derived from the tiles and the parcel rows. Call after any edit.
func rebuild() -> void:
	_build_field()
	_build_distance()
	_parcel_sale.clear()
	starts.clear()
	for y in range(parcels.size()):
		for x in range(parcels[y].length()):
			if parcels[y][x] == "S":
				starts.append(Vector2i(x, y))

# ---------------------------------------------------------------- tiles, walls, parcels

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cells.x and c.y < cells.y

func tile_at(c: Vector2i) -> int:
	return tiles[c.y * cells.x + c.x] if in_bounds(c) else Tile.WATER

func set_tile(c: Vector2i, t: int) -> void:
	if in_bounds(c):
		tiles[c.y * cells.x + c.x] = t

func is_road(c: Vector2i) -> bool:
	return tile_at(c) == Tile.ROAD

static func wall_key(c: Vector2i, edge: String) -> String:
	return "%d,%d,%s" % [c.x, c.y, edge]

func wall_at(c: Vector2i, edge: String) -> String:
	return str(walls.get(wall_key(c, edge), ""))

# The wall edge nearest to a float cell position: {cell, edge} where edge "n" is the north face of the cell and
# "w" its west face (the south and east faces of a cell are the north / west faces of its neighbours).
static func nearest_edge(pos: Vector2) -> Dictionary:
	var i := floori(pos.x + 0.5)
	var j := floori(pos.y + 0.5)
	var ux := pos.x - i
	var uy := pos.y - j
	var d_w := ux + 0.5
	var d_e := 0.5 - ux
	var d_n := uy + 0.5
	var d_s := 0.5 - uy
	var m := minf(minf(d_w, d_e), minf(d_n, d_s))
	if m == d_w:
		return {"cell": Vector2i(i, j), "edge": "w"}
	if m == d_e:
		return {"cell": Vector2i(i + 1, j), "edge": "w"}
	if m == d_n:
		return {"cell": Vector2i(i, j), "edge": "n"}
	return {"cell": Vector2i(i, j + 1), "edge": "n"}

# Edges run along the outer border too: a "w" edge may sit at x == cells.x and an "n" edge at y == cells.y.
func edge_in_bounds(c: Vector2i, edge: String) -> bool:
	if edge == "w":
		return c.x >= 0 and c.y >= 0 and c.x <= cells.x and c.y < cells.y
	if edge == "n":
		return c.x >= 0 and c.y >= 0 and c.x < cells.x and c.y <= cells.y
	return false

func set_wall(c: Vector2i, edge: String, kind: String) -> void:
	if not edge_in_bounds(c, edge):
		return
	if kind == "" or not WALL_KINDS.has(kind):
		walls.erase(wall_key(c, edge))
	else:
		walls[wall_key(c, edge)] = kind

func parcel_rows() -> Vector2i:
	return cells / WorldGrid.PARCEL

func label_of_parcel(p: Vector2i) -> String:
	if p.y < 0 or p.y >= parcels.size() or p.x < 0 or p.x >= parcels[p.y].length():
		return ""
	return parcels[p.y][p.x]

func set_parcel_label(p: Vector2i, label: String) -> void:
	if p.y < 0 or p.y >= parcels.size() or p.x < 0 or p.x >= parcels[p.y].length():
		return
	var row := parcels[p.y]
	parcels[p.y] = row.left(p.x) + label + row.substr(p.x + 1)
	_parcel_sale.clear()
	starts.clear()
	for y in range(parcels.size()):
		for x in range(parcels[y].length()):
			if parcels[y][x] == "S":
				starts.append(Vector2i(x, y))

func label_of_cell(c: Vector2i) -> String:
	return label_of_parcel(WorldGrid.parcel_of(c))

func is_start_parcel(p: Vector2i) -> bool:
	return label_of_parcel(p) == "S"

# A block is for sale when it is marked 'B' and enough of it is dry land (a sign must stand on land).
func for_sale(p: Vector2i) -> bool:
	if label_of_parcel(p) != "B":
		return false
	if not _parcel_sale.has(p):
		var n := 0
		for y in range(WorldGrid.PARCEL):
			for x in range(WorldGrid.PARCEL):
				if is_solid(p * WorldGrid.PARCEL + Vector2i(x, y)):
					n += 1
		_parcel_sale[p] = n >= 12 and is_solid(p * WorldGrid.PARCEL + Vector2i.ONE * (WorldGrid.PARCEL / 2))
	return _parcel_sale[p]

func sale_parcels() -> Dictionary:
	var out := {}
	for y in range(parcels.size()):
		for x in range(parcels[y].length()):
			if for_sale(Vector2i(x, y)):
				out[Vector2i(x, y)] = true
	return out

# Whether an item of placement group `group` ("restaurant", "farm") may stand on cell `c`: ground it can be built on.
func allows(group: String, c: Vector2i) -> bool:
	if not (area == "any" or area == group):
		return false
	var t := tile_at(c)
	return t != Tile.WATER and t != Tile.ROAD

# Cell in the middle of the first group of touching starting blocks (where the camera starts). A map with
# several separate starting areas (the shop and the farm) starts at the first one.
func start_cell() -> Vector2i:
	if starts.is_empty():
		return cells / 2
	var first: Vector2i = starts[0]
	for p in starts:
		if p.y < first.y or (p.y == first.y and p.x < first.x):
			first = p
	var group: Array[Vector2i] = [first]
	var i := 0
	while i < group.size():
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = group[i] + d
			if starts.has(q) and not group.has(q):
				group.append(q)
		i += 1
	var sum := Vector2.ZERO
	for p in group:
		sum += Vector2(p * WorldGrid.PARCEL + Vector2i.ONE * (WorldGrid.PARCEL / 2))
	return Vector2i((sum / group.size()).round())

# ---------------------------------------------------------------- coast

func _vertex_size() -> Vector2i:
	return cells + Vector2i.ONE

# Every corner takes a weighted share of the cells around it (land +1, water -1): the shoreline then runs
# smoothly instead of along cell edges, and a pond smaller than two cells fades away.
func _build_field() -> void:
	var vs := _vertex_size()
	field = PackedFloat32Array()
	field.resize(vs.x * vs.y)
	for vy in range(vs.y):
		for vx in range(vs.x):
			var sum := 0.0
			var weight := 0.0
			for dy in range(-2, 2):
				for dx in range(-2, 2):
					var cx := clampi(vx + dx, 0, cells.x - 1)
					var cy := clampi(vy + dy, 0, cells.y - 1)
					var w := 4.0 if (dx >= -1 and dx <= 0 and dy >= -1 and dy <= 0) else 1.0
					sum += w * (-1.0 if tiles[cy * cells.x + cx] == Tile.WATER else 1.0)
					weight += w
			field[vy * vs.x + vx] = sum / weight

func vertex_field(vx: int, vy: int) -> float:
	var vs := _vertex_size()
	if vx < 0 or vy < 0 or vx >= vs.x or vy >= vs.y:
		return -1.0
	return field[vy * vs.x + vx]

# Chamfer distance, in cells, from a corner to the nearest water corner (large when the map has no water).
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
	if not in_bounds(c) or tile_at(c) == Tile.WATER:
		return false
	for f in _corners_of(c):
		if f <= 0.0:
			return false
	return true

# True when any part of the cell is land (it may be drawn as a partial cell on the shore).
func has_land(c: Vector2i) -> bool:
	if not in_bounds(c):
		return false
	for f in _corners_of(c):
		if f > 0.0:
			return true
	return false

# Whole cells between this cell and the water (-1 in the water, 99 on a map without water).
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
