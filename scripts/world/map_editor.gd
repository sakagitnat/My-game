class_name MapEditor
extends RefCounted

# The owner's map editor. Works on copies of the scenes' maps (SceneLayout) that are installed into GameState
# while editing; every change rebuilds the scene's grid from the map so what is drawn is what the map says.
# Strokes are undoable (whole-map snapshots: maps are small). Nothing here touches the screen: world.gd feeds it
# pointer positions and EditorUI picks the tool.

signal changed

const MAX_UNDO := 40
const TOOLS := ["hand", "ground", "wall", "prop", "land", "erase"]
const LAND_LABELS := [".", "B", "S"]
const MAX_BLOCKS := Vector2i(16, 16)
const MIN_BLOCKS := Vector2i(3, 3)

var zone := "restaurant"
var tool := "ground"
var tile: int = SceneLayout.Tile.GRASS
var wall_kind := "wall"
var prop_id := "tree"                 # a key of Catalog.OBSTACLES or Catalog.PLACEABLES
var land_label := "B"
var brush := 1
var erase_walls := false              # the erase tool removes walls instead of items
var layouts: Dictionary = {}          # scene -> the copy being edited
var originals: Dictionary = {}        # scene -> its map when editing began
var edited: Dictionary = {}           # scenes that were changed
var _undo: Array = []
var _redo: Array = []
var _stroke_open := false
var _stroke_changed := false
var _dirty := false
var _last_edge := ""

func begin(start_zone: String) -> void:
	zone = start_zone
	for z in Catalog.ZONES:
		originals[z] = GameState.layout_for(z).to_dict()
		layouts[z] = SceneLayout.from_dict(originals[z])
		GameState.layouts[z] = layouts[z]

func current() -> SceneLayout:
	return layouts[zone]

func set_zone(z: String) -> void:
	flush()
	zone = z
	_undo.clear()
	_redo.clear()

func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()

# ---------------------------------------------------------------- strokes

func begin_stroke() -> void:
	_undo.append(current().to_dict())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()
	_stroke_open = true
	_stroke_changed = false
	_last_edge = ""

# Applies the current tool at a world position. Returns false when nothing could be done there.
func apply_at(world_pos: Vector2) -> bool:
	var fpos := Iso.world_to_cell_f(world_pos)
	var cell := Vector2i(floori(fpos.x + 0.5), floori(fpos.y + 0.5))
	var did := false
	match tool:
		"ground": did = _paint_ground(cell)
		"wall": did = _paint_wall(fpos, wall_kind)
		"prop": did = _place_prop(cell, Iso.world_to_unit(world_pos))
		"land": did = _set_land(cell)
		"erase": did = _erase(cell, fpos)
	if did:
		_stroke_changed = true
		_dirty = true
	return did

func end_stroke() -> void:
	if not _stroke_open:
		return
	_stroke_open = false
	if not _stroke_changed:
		_undo.pop_back()
	flush()

var _flush_timer := 0.0

# During a long stroke the scene is rebuilt about every tenth of a second, not for every cell touched.
func flush_if_due(delta: float) -> void:
	_flush_timer += delta
	if _flush_timer >= 0.12:
		_flush_timer = 0.0
		flush()

# Rebuilds what depends on the map. Called at the end of a stroke and now and then during one.
func flush() -> void:
	if not _dirty:
		return
	_dirty = false
	_refresh()

func _refresh() -> void:
	var l := current()
	l.prune_props()
	l.rebuild()
	GameState.build_zone(zone)
	edited[zone] = true
	changed.emit()

func _paint_ground(cell: Vector2i) -> bool:
	var l := current()
	var did := false
	var lo := -((brush - 1) / 2)
	for dy in range(brush):
		for dx in range(brush):
			var c := cell + Vector2i(lo + dx, lo + dy)
			if l.in_bounds(c) and l.tile_at(c) != tile:
				l.set_tile(c, tile)
				did = true
	return did

func _paint_wall(fpos: Vector2, kind: String) -> bool:
	var l := current()
	var e := SceneLayout.nearest_edge(fpos)
	if not l.edge_in_bounds(e.cell, e.edge):
		return false
	if l.wall_at(e.cell, e.edge) == kind:
		return false
	l.set_wall(e.cell, e.edge, kind)
	return true

func _set_land(cell: Vector2i) -> bool:
	var l := current()
	var p := WorldGrid.parcel_of(cell)
	if l.label_of_parcel(p) == "" or l.label_of_parcel(p) == land_label:
		return false
	l.set_parcel_label(p, land_label)
	return true

# Units covered by the objects already on the map (objects are placed in units, see Iso.SUB).
func _object_cells(l: SceneLayout, skip: int = -1) -> Dictionary:
	var out := {}
	for i in range(l.objects.size()):
		if i == skip:
			continue
		var o: Array = l.objects[i]
		var sz: Vector2i = Catalog.size_of(str(o[2]))
		for y in range(sz.y):
			for x in range(sz.x):
				out[Vector2i(o[0] + x, o[1] + y)] = i
	return out

func _obstacle_at(l: SceneLayout, c: Vector2i) -> int:
	for i in range(l.obstacles.size()):
		if l.obstacles[i][0] == c.x and l.obstacles[i][1] == c.y:
			return i
	return -1

func _unit_has_object(occupied: Dictionary, cell: Vector2i) -> bool:
	for dy in range(Iso.SUB):
		for dx in range(Iso.SUB):
			if occupied.has(cell * Iso.SUB + Vector2i(dx, dy)):
				return true
	return false

func _place_prop(cell: Vector2i, unit: Vector2i) -> bool:
	var l := current()
	var occupied := _object_cells(l)
	if Catalog.OBSTACLES.has(prop_id):
		if not l.is_solid(cell) or _unit_has_object(occupied, cell) or _obstacle_at(l, cell) >= 0:
			return false
		var t := l.tile_at(cell)
		if t != SceneLayout.Tile.GRASS and t != SceneLayout.Tile.SAND and t != SceneLayout.Tile.DIRT:
			return false
		l.obstacles.append([cell.x, cell.y, prop_id])
		return true
	if not Catalog.PLACEABLES.has(prop_id) or Catalog.is_top(prop_id):
		return false
	var sz: Vector2i = Catalog.size_of(prop_id)
	var origin := GameState.footprint_origin(unit, sz)
	for y in range(sz.y):
		for x in range(sz.x):
			var u := origin + Vector2i(x, y)
			var c := Iso.cell_of_unit(u)
			if not l.is_solid(c) or not l.allows(str(Catalog.PLACEABLES[prop_id].area), c) or occupied.has(u) or _obstacle_at(l, c) >= 0:
				return false
	l.objects.append([origin.x, origin.y, prop_id])
	return true

func _erase(cell: Vector2i, fpos: Vector2) -> bool:
	var l := current()
	if erase_walls:
		var e := SceneLayout.nearest_edge(fpos)
		if l.wall_at(e.cell, e.edge) == "":
			return false
		l.set_wall(e.cell, e.edge, "")
		return true
	var did := false
	var oi := _obstacle_at(l, cell)
	if oi >= 0:
		l.obstacles.remove_at(oi)
		did = true
	var cells := _object_cells(l)
	var unit := Iso.world_to_unit(Iso.cell_to_world_f(fpos))
	if cells.has(unit):
		l.objects.remove_at(cells[unit])
		did = true
	return did

# ---------------------------------------------------------------- undo, size, text

func undo() -> void:
	if _undo.is_empty():
		return
	flush()
	_redo.append(current().to_dict())
	current().copy_from(SceneLayout.from_dict(_undo.pop_back()))
	_refresh()

func redo() -> void:
	if _redo.is_empty():
		return
	flush()
	_undo.append(current().to_dict())
	current().copy_from(SceneLayout.from_dict(_redo.pop_back()))
	_refresh()

# Grows or shrinks the map by whole land blocks (6 cells). Returns false at the limits.
func resize_by(delta_blocks: Vector2i) -> bool:
	var l := current()
	var target := l.cells / WorldGrid.PARCEL + delta_blocks
	if target.x < MIN_BLOCKS.x or target.y < MIN_BLOCKS.y or target.x > MAX_BLOCKS.x or target.y > MAX_BLOCKS.y:
		return false
	begin_stroke()
	l.resize(target)
	_stroke_changed = true
	_dirty = true
	end_stroke()
	return true

func export_text() -> String:
	return MapStore.to_text(current())

# Replaces the map with pasted text. Returns "ok" or "invalid".
func import_text(text: String) -> String:
	var d := MapStore.parse(text.strip_edges())
	if d.is_empty() or not d.has("tiles") or not d.has("size"):
		return "invalid"
	var size = d.get("size")
	if not (size is Array) or size.size() != 2:
		return "invalid"
	var blocks := Vector2i(int(size[0]), int(size[1])) / WorldGrid.PARCEL
	if int(size[0]) % WorldGrid.PARCEL != 0 or int(size[1]) % WorldGrid.PARCEL != 0 or blocks.x < MIN_BLOCKS.x or blocks.y < MIN_BLOCKS.y or blocks.x > MAX_BLOCKS.x or blocks.y > MAX_BLOCKS.y:
		return "invalid"
	d["id"] = zone
	d["area"] = current().area
	begin_stroke()
	current().copy_from(SceneLayout.from_dict(d))
	_stroke_changed = true
	_dirty = true
	end_stroke()
	return "ok"

func reset_to_shipped() -> void:
	begin_stroke()
	current().copy_from(MapStore.load_layout(zone, false))
	_stroke_changed = true
	_dirty = true
	end_stroke()

# ---------------------------------------------------------------- leaving

func save() -> bool:
	flush()
	var ok := true
	for z in edited:
		ok = MapStore.save_user(layouts[z]) and ok
	return ok

# Leaves the editor. keep = true saves the edited maps to user storage; false puts the old maps back.
func finish(keep: bool) -> void:
	flush()
	if keep:
		save()
	else:
		for z in edited:
			GameState.layouts[z] = SceneLayout.from_dict(originals[z])
			GameState.build_zone(z)
	if GameState.autosave:
		GameState.save_game()
	GameState.changed.emit()
