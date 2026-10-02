class_name WorldGrid
extends RefCounted

# Land is owned in PARCEL x PARCEL blocks of cells. Objects cover one or more
# cells, are keyed by their top-left "origin" cell and may only sit on owned land.
const PARCEL := 6
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const NONE := Vector2i(-9999, -9999)

var size: Vector2i
var start_parcel_count: int = 0
var owned_parcels: Dictionary = {}
var objects: Dictionary = {}
var footprints: Dictionary = {}
var occupied: Dictionary = {}
var states: Dictionary = {}

func _init(grid_size: Vector2i = Vector2i(30, 30), start_parcels: Array = []) -> void:
	size = grid_size
	for p in start_parcels:
		owned_parcels[p] = true
	start_parcel_count = owned_parcels.size()

static func parcel_of(c: Vector2i) -> Vector2i:
	return Vector2i(floori(c.x / float(PARCEL)), floori(c.y / float(PARCEL)))

func parcel_grid() -> Vector2i:
	return size / PARCEL

func parcel_in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < parcel_grid().x and p.y < parcel_grid().y

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y

func is_owned(c: Vector2i) -> bool:
	return in_bounds(c) and owned_parcels.has(parcel_of(c))

func bought_count() -> int:
	return owned_parcels.size() - start_parcel_count

func can_buy_parcel(p: Vector2i) -> bool:
	if not parcel_in_bounds(p) or owned_parcels.has(p):
		return false
	for d in DIRS:
		if owned_parcels.has(p + d):
			return true
	return false

func buy_parcel(p: Vector2i) -> bool:
	if not can_buy_parcel(p):
		return false
	owned_parcels[p] = true
	return true

func cells_of(origin: Vector2i, sz: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(sz.y):
		for x in range(sz.x):
			out.append(origin + Vector2i(x, y))
	return out

func footprint_in_bounds(origin: Vector2i, sz: Vector2i) -> bool:
	return in_bounds(origin) and in_bounds(origin + sz - Vector2i.ONE)

func footprint_owned(origin: Vector2i, sz: Vector2i) -> bool:
	for c in cells_of(origin, sz):
		if not is_owned(c):
			return false
	return true

func footprint_free(origin: Vector2i, sz: Vector2i) -> bool:
	for c in cells_of(origin, sz):
		if occupied.has(c):
			return false
	return true

func can_place(origin: Vector2i, sz: Vector2i) -> bool:
	return footprint_in_bounds(origin, sz) and footprint_owned(origin, sz) and footprint_free(origin, sz)

func place(origin: Vector2i, id: String, sz: Vector2i) -> bool:
	if not can_place(origin, sz):
		return false
	objects[origin] = id
	footprints[origin] = sz
	for c in cells_of(origin, sz):
		occupied[c] = origin
	return true

# Origin of the object covering cell `c`, or NONE.
func origin_at(c: Vector2i) -> Vector2i:
	return occupied.get(c, NONE)

func id_at(c: Vector2i) -> String:
	return objects.get(origin_at(c), "")

func remove_at(c: Vector2i) -> String:
	var origin := origin_at(c)
	if origin == NONE:
		return ""
	var id: String = objects[origin]
	for cell in cells_of(origin, footprints[origin]):
		occupied.erase(cell)
	objects.erase(origin)
	footprints.erase(origin)
	states.erase(origin)
	return id

func to_dict() -> Dictionary:
	var parcels: Array = []
	for p in owned_parcels:
		parcels.append([p.x, p.y])
	var obj: Array = []
	for o in objects:
		obj.append([o.x, o.y, objects[o], footprints[o].x, footprints[o].y])
	var st: Array = []
	for o in states:
		st.append([o.x, o.y, states[o]])
	return {"size": [size.x, size.y], "parcel": PARCEL, "start": start_parcel_count,
		"parcels": parcels, "objects": obj, "states": st}

# Returns false (leaving the grid untouched) for saves from before parcels existed.
func load_dict(d: Dictionary) -> bool:
	if not d.has("parcels") or int(d.get("parcel", 0)) != PARCEL:
		return false
	owned_parcels.clear()
	objects.clear()
	footprints.clear()
	occupied.clear()
	states.clear()
	for p in d.get("parcels", []):
		var pc := Vector2i(int(p[0]), int(p[1]))
		if parcel_in_bounds(pc):
			owned_parcels[pc] = true
	start_parcel_count = clampi(int(d.get("start", 1)), 0, owned_parcels.size())
	for o in d.get("objects", []):
		var origin := Vector2i(int(o[0]), int(o[1]))
		place(origin, str(o[2]), Vector2i(int(o[3]), int(o[4])))
	for s in d.get("states", []):
		var origin := Vector2i(int(s[0]), int(s[1]))
		if objects.has(origin) and s[2] is Dictionary:
			states[origin] = s[2]
	return true
