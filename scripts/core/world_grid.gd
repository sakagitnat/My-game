class_name WorldGrid
extends RefCounted

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var size: Vector2i
var start_owned_count: int = 0
var owned: Dictionary = {}
var objects: Dictionary = {}
var states: Dictionary = {}

func _init(grid_size: Vector2i = Vector2i(10, 10), start_cells: Array = []) -> void:
	size = grid_size
	for c in start_cells:
		owned[c] = true
	start_owned_count = owned.size()

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y

func is_owned(c: Vector2i) -> bool:
	return owned.has(c)

func bought_count() -> int:
	return owned.size() - start_owned_count

func can_place(c: Vector2i) -> bool:
	return in_bounds(c) and owned.has(c) and not objects.has(c)

func place(c: Vector2i, id: String) -> bool:
	if not can_place(c):
		return false
	objects[c] = id
	return true

func remove(c: Vector2i) -> String:
	if not objects.has(c):
		return ""
	var id: String = objects[c]
	objects.erase(c)
	states.erase(c)
	return id

func can_buy(c: Vector2i) -> bool:
	if not in_bounds(c) or owned.has(c):
		return false
	for d in DIRS:
		if owned.has(c + d):
			return true
	return false

func buy(c: Vector2i) -> bool:
	if not can_buy(c):
		return false
	owned[c] = true
	return true

func to_dict() -> Dictionary:
	var o: Array = []
	for c in owned:
		o.append([c.x, c.y])
	var obj: Array = []
	for c in objects:
		obj.append([c.x, c.y, objects[c]])
	var st: Array = []
	for c in states:
		st.append([c.x, c.y, states[c]])
	return {"size": [size.x, size.y], "start": start_owned_count, "owned": o, "objects": obj, "states": st}

func load_dict(d: Dictionary) -> void:
	owned.clear()
	objects.clear()
	states.clear()
	for p in d.get("owned", []):
		var c := Vector2i(int(p[0]), int(p[1]))
		if in_bounds(c):
			owned[c] = true
	for p in d.get("objects", []):
		var c := Vector2i(int(p[0]), int(p[1]))
		if owned.has(c):
			objects[c] = str(p[2])
	for p in d.get("states", []):
		var c := Vector2i(int(p[0]), int(p[1]))
		if objects.has(c) and p[2] is Dictionary:
			states[c] = p[2]
	start_owned_count = clampi(int(d.get("start", start_owned_count)), 0, owned.size())
