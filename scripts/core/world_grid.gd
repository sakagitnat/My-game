class_name WorldGrid
extends RefCounted

# Land is owned in PARCEL x PARCEL blocks of cells. Objects are counted in finer "units" (Iso.SUB x Iso.SUB per cell):
# they cover one or more units, are keyed by their top-left "origin" unit and may only sit on owned land.
# `occupied`, `objects`, `footprints`, `states` and `facings` are all in units; land, `blocked` and `styles` stay in cells.
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
var blocked: Dictionary = {}
var sale: Dictionary = {}         # parcels the player may buy; empty means every parcel
var facings: Dictionary = {}      # origin -> 1..3 for objects turned away from the front (0 is not stored)
var tops: Dictionary = {}         # origin -> id of small things standing on a surface object (vases, cups), their own layer
var top_footprints: Dictionary = {}
var top_occupied: Dictionary = {} # unit -> origin of the top thing on it
var styles: Dictionary = {}       # parcel -> "floor" for blocks built over as indoor floor (everything else is open ground)

func _init(grid_size: Vector2i = Vector2i(30, 30), start_parcels: Array = [], sale_parcels: Dictionary = {}) -> void:
	size = grid_size
	sale = sale_parcels
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
	if not sale.is_empty() and not sale.has(p):
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

func has_floor(p: Vector2i) -> bool:
	return styles.get(p, "") == "floor"

func set_floor(p: Vector2i, floor_on: bool) -> void:
	if floor_on:
		styles[p] = "floor"
	else:
		styles.erase(p)

func cells_of(origin: Vector2i, sz: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(sz.y):
		for x in range(sz.x):
			out.append(origin + Vector2i(x, y))
	return out

# `origin` and `sz` are in units.
func footprint_in_bounds(origin: Vector2i, sz: Vector2i) -> bool:
	return origin.x >= 0 and origin.y >= 0 and origin.x + sz.x <= size.x * Iso.SUB and origin.y + sz.y <= size.y * Iso.SUB

func footprint_owned(origin: Vector2i, sz: Vector2i) -> bool:
	for u in cells_of(origin, sz):
		if not is_owned(Iso.cell_of_unit(u)):
			return false
	return true

# Whether any unit of cell `c` holds part of an object.
# Whether people cannot walk through unit `u`: a tree, rock or bush on its cell, or the blocking part of an object there
# (Catalog.block_rect, which can be smaller than the room the object reserves). Things on tables never block.
func blocks_walk(u: Vector2i) -> bool:
	if blocked.has(Iso.cell_of_unit(u)):
		return true
	var origin: Vector2i = occupied.get(u, NONE)
	if origin == NONE:
		return false
	var r := Catalog.block_rect(str(objects[origin]), facing_at(origin))
	return r.has_point(u - origin)

func cell_occupied(c: Vector2i) -> bool:
	for dy in range(Iso.SUB):
		for dx in range(Iso.SUB):
			if occupied.has(c * Iso.SUB + Vector2i(dx, dy)):
				return true
	return false

# A unit may hold an object when it lies on owned land with no tree, rock or bush.
func _unit_usable(u: Vector2i) -> bool:
	var c := Iso.cell_of_unit(u)
	return in_bounds(c) and is_owned(c) and not blocked.has(c)

func footprint_free(origin: Vector2i, sz: Vector2i) -> bool:
	for c in cells_of(origin, sz):
		if occupied.has(c):
			return false
	return true

# True if a tree, rock or bush stands on any cell of the footprint.
func footprint_blocked(origin: Vector2i, sz: Vector2i) -> bool:
	for u in cells_of(origin, sz):
		if blocked.has(Iso.cell_of_unit(u)):
			return true
	return false

func can_place(origin: Vector2i, sz: Vector2i) -> bool:
	return footprint_in_bounds(origin, sz) and footprint_owned(origin, sz) and footprint_free(origin, sz) and not footprint_blocked(origin, sz)

func place(origin: Vector2i, id: String, sz: Vector2i, facing: int = 0) -> bool:
	if not can_place(origin, sz):
		return false
	objects[origin] = id
	footprints[origin] = sz
	if facing != 0:
		facings[origin] = facing
	for c in cells_of(origin, sz):
		occupied[c] = origin
	return true

# Moves the object at `origin` so its top-left cell is `new_origin`, keeping its state. False if it does not fit.
func move(origin: Vector2i, new_origin: Vector2i) -> bool:
	if not objects.has(origin):
		return false
	var sz: Vector2i = footprints[origin]
	for c in cells_of(new_origin, sz):
		if not _unit_usable(c) or (occupied.has(c) and occupied[c] != origin):
			return false
	var id: String = objects[origin]
	var st = states.get(origin)
	var facing := facing_at(origin)
	var carried := tops_over(origin)   # what stands on it goes along
	for c in cells_of(origin, sz):
		occupied.erase(c)
	objects.erase(origin)
	footprints.erase(origin)
	states.erase(origin)
	facings.erase(origin)
	var delta := new_origin - origin
	var carried_info: Array = []
	for t in carried:
		carried_info.append([t, tops[t], top_footprints[t]])
		remove_top_at(t)
	place(new_origin, id, sz, facing)
	if st != null:
		states[new_origin] = st
	for info in carried_info:
		place_top(info[0] + delta, info[1], info[2])
	return true

# ---- The top layer: small things on tables

# "ok", "invalid" (off the map or on unusable land), "no_surface" (some unit is not over a table) or "occupied" (another top thing is there).
# `ignore` is the origin of a top thing being moved, which does not block itself.
func top_status(origin: Vector2i, sz: Vector2i, ignore: Vector2i = NONE) -> String:
	if not footprint_in_bounds(origin, sz):
		return "invalid"
	for u in cells_of(origin, sz):
		if not occupied.has(u) or not Catalog.is_surface(str(objects[occupied[u]])):
			return "no_surface"
	for u in cells_of(origin, sz):
		if top_occupied.has(u) and top_occupied[u] != ignore:
			return "occupied"
	return "ok"

func place_top(origin: Vector2i, id: String, sz: Vector2i) -> bool:
	if top_status(origin, sz) != "ok":
		return false
	tops[origin] = id
	top_footprints[origin] = sz
	for u in cells_of(origin, sz):
		top_occupied[u] = origin
	return true

func top_origin_at(u: Vector2i) -> Vector2i:
	return top_occupied.get(u, NONE)

func remove_top_at(u: Vector2i) -> String:
	var origin := top_origin_at(u)
	if origin == NONE:
		return ""
	var id: String = tops[origin]
	for c in cells_of(origin, top_footprints[origin]):
		top_occupied.erase(c)
	tops.erase(origin)
	top_footprints.erase(origin)
	return id

# Origins of the top things standing on the floor object at `origin`.
func tops_over(origin: Vector2i) -> Array:
	var out: Array = []
	if not objects.has(origin):
		return out
	for u in cells_of(origin, footprints[origin]):
		var t: Vector2i = top_occupied.get(u, NONE)
		if t != NONE and not out.has(t):
			out.append(t)
	return out

# Moves a top thing so its top-left unit is `new_origin`. False, changing nothing, if it does not fit there.
func move_top(origin: Vector2i, new_origin: Vector2i) -> bool:
	if not tops.has(origin):
		return false
	var sz: Vector2i = top_footprints[origin]
	if top_status(new_origin, sz, origin) != "ok":
		return false
	var id: String = tops[origin]
	remove_top_at(origin)
	return place_top(new_origin, id, sz)

func facing_at(origin: Vector2i) -> int:
	return int(facings.get(origin, 0))

# Turns the object at `origin` a quarter turn (0 front, 1 left, 2 back, 3 right) keeping its state. `new_sz` is the footprint after
# the turn and `new_origin` its top-left unit (default: the same one; Catalog.origin_after_turn gives the one that turns it about
# its middle). Things standing on it (tops) stay where they are, so a thing with tops cannot be turned. False, changing nothing,
# if it does not fit.
func turn(origin: Vector2i, new_sz: Vector2i, new_origin: Vector2i = NONE) -> bool:
	if not objects.has(origin):
		return false
	if new_origin == NONE:
		new_origin = origin
	if not tops_over(origin).is_empty():
		return false
	for c in cells_of(new_origin, new_sz):
		if not _unit_usable(c) or (occupied.has(c) and occupied[c] != origin):
			return false
	var id: String = objects[origin]
	var st = states.get(origin)
	var f := (facing_at(origin) + 1) % 4
	for c in cells_of(origin, footprints[origin]):
		occupied.erase(c)
	objects.erase(origin)
	footprints.erase(origin)
	states.erase(origin)
	facings.erase(origin)
	objects[new_origin] = id
	footprints[new_origin] = new_sz
	for c in cells_of(new_origin, new_sz):
		occupied[c] = new_origin
	if f != 0:
		facings[new_origin] = f
	if st != null:
		states[new_origin] = st
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
	for t in tops_over(origin):
		remove_top_at(t)
	for cell in cells_of(origin, footprints[origin]):
		occupied.erase(cell)
	objects.erase(origin)
	footprints.erase(origin)
	states.erase(origin)
	facings.erase(origin)
	return id

func to_dict() -> Dictionary:
	var parcels: Array = []
	for p in owned_parcels:
		parcels.append([p.x, p.y])
	var obj: Array = []
	for o in objects:
		obj.append([o.x, o.y, objects[o], footprints[o].x, footprints[o].y])
	var top_list: Array = []
	for o in tops:
		top_list.append([o.x, o.y, tops[o], top_footprints[o].x, top_footprints[o].y])
	var fac: Array = []
	for o in facings:
		fac.append([o.x, o.y, facings[o]])
	var st: Array = []
	for o in states:
		st.append([o.x, o.y, states[o]])
	var obs: Array = []
	for c in blocked:
		obs.append([c.x, c.y, blocked[c]])
	var floors: Array = []
	for p in styles:
		floors.append([p.x, p.y])
	return {"size": [size.x, size.y], "parcel": PARCEL, "start": start_parcel_count,
		"units": Iso.SUB, "parcels": parcels, "objects": obj, "tops": top_list, "facings": fac, "states": st, "obstacles": obs, "floors": floors}

# Returns false (leaving the grid untouched) for saves from before parcels existed or of a different map size.
func load_dict(d: Dictionary) -> bool:
	if not d.has("parcels") or int(d.get("parcel", 0)) != PARCEL:
		return false
	var sz = d.get("size", [])
	if sz is Array and sz.size() == 2 and (int(sz[0]) != size.x or int(sz[1]) != size.y):
		return false
	owned_parcels.clear()
	objects.clear()
	footprints.clear()
	occupied.clear()
	states.clear()
	facings.clear()
	tops.clear()
	top_footprints.clear()
	top_occupied.clear()
	blocked.clear()
	styles.clear()
	for p in d.get("parcels", []):
		var pc := Vector2i(int(p[0]), int(p[1]))
		if parcel_in_bounds(pc):
			owned_parcels[pc] = true
	for f in d.get("floors", []):
		var fc := Vector2i(int(f[0]), int(f[1]))
		if owned_parcels.has(fc):
			styles[fc] = "floor"
	start_parcel_count = clampi(int(d.get("start", 1)), 0, owned_parcels.size())
	# saves from before the finer grid count objects in whole cells: scale them up to units
	var k := Iso.SUB / maxi(1, int(d.get("units", 1)))
	for o in d.get("objects", []):
		var origin := Vector2i(int(o[0]), int(o[1])) * k
		place(origin, str(o[2]), Vector2i(int(o[3]), int(o[4])) * k)
	for t in d.get("tops", []):
		place_top(Vector2i(int(t[0]), int(t[1])), str(t[2]), Vector2i(int(t[3]), int(t[4])))
	for f in d.get("facings", []):
		var fo := Vector2i(int(f[0]), int(f[1])) * k
		if objects.has(fo):
			facings[fo] = clampi(int(f[2]), 1, 3)
	for s in d.get("states", []):
		var origin := Vector2i(int(s[0]), int(s[1])) * k
		if objects.has(origin) and s[2] is Dictionary:
			states[origin] = s[2]
	for o in d.get("obstacles", []):
		var cell := Vector2i(int(o[0]), int(o[1]))
		if in_bounds(cell) and not cell_occupied(cell) and Catalog.OBSTACLES.has(str(o[2])):
			blocked[cell] = str(o[2])
	return true
