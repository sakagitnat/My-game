class_name SceneDecor
extends Node2D

# Drawn from a scene's SceneLayout and the player's land (GameState): the ground kinds the owner painted
# (road, pavement, floor, sand, dirt), floor built over bought land, the walls on cell edges, and the build grid
# shown while placing or moving. Reads only. Colours and shapes are code-drawn stand-ins until art arrives.
const WALL_H := 192.0      # a wall is three blocks (cells) tall (art: 128x384 for one cell wide); a door is two, a counter one
const LOW_H := 32.0
const SIDE_W := 16.0       # thickness of a wall seen from the side (art: 32x384)
const FLOOR_A := Color("ead3a8")
const FLOOR_B := Color("d9bb8b")
const ROAD := Color("b79a6a")
const ROAD_DARK := Color("a58a5c")
const PAVEMENT := Color("d6cdb9")
const SAND := Color("ecd9a4")
const DIRT := Color("9a7a52")
const WALL := Color("f3e4c4")
const WALL_SIDE := Color("e3d0a8")
const BASEBOARD := Color("a3714a")
const TRIM := Color("7a5233")
const GLASS := Color("bfe3f2")
const WHITE_FRAME := Color("fffaf0")
const GRID := Color(1, 1, 1, 0.34)

# Art ids tried first; when no such file is in assets/td, the code-drawn colours below are used instead.
# Ground tiles are 128x128 (drawn at 64 px), each ground kind can have several variants (_01, _02 ...) picked per
# cell. Walls: plain wall 128x384, low wall 128x64, side wall 32x384; windows, doors, lamps and paintings are
# separate overlays on a plain wall (docs/ART_TOPDOWN.md).
const TILE_ART := {
	SceneLayout.Tile.SAND: ["tile_sand_01"],
	SceneLayout.Tile.DIRT: ["tile_dirt_01"],
	SceneLayout.Tile.ROAD: ["tile_road_dirt_01", "tile_road_dirt_02", "tile_road_dirt_03"],
	SceneLayout.Tile.PAVEMENT: ["tile_pavement_01", "tile_pavement_02"],
	SceneLayout.Tile.FLOOR: ["tile_floor_01", "tile_floor_02"],   # tile_floor_03 is the kitchen floor (no ground kind for it yet)
}
const WALL_ART := {"wall": "wall_plain_01", "low": "wall_low_01"}
const WALL_SIDE_ART := "wall_side_01"
const WALL_OVERLAY := {"window": "wdeco_window_01", "door": "wdeco_door_01"}

# Ground kinds that melt into each other: along a border the higher rank is laid over the lower one with a soft edge.
# Road, pavement and floor have hard edges. Art (128x128, transparent) is tried first, named edge_<kind>_<side>_01 for a
# neighbour on that side (n, e, s, w) and corner_<kind>_<corner>_01 for one only on the diagonal (ne, se, sw, nw);
# without art a soft gradient of the neighbour's colour is drawn.
const BLEND_RANK := {SceneLayout.Tile.SAND: 1, SceneLayout.Tile.DIRT: 2, SceneLayout.Tile.GRASS: 3}
const BLEND_NAME := {SceneLayout.Tile.DIRT: "dirt", SceneLayout.Tile.GRASS: "grass"}
const BLEND_DEPTH := 0.42   # how far into the lower cell the soft edge reaches, in cells
const SIDES := {"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "w": Vector2i(-1, 0)}
const CORNERS := {"ne": Vector2i(1, -1), "se": Vector2i(1, 1), "sw": Vector2i(-1, 1), "nw": Vector2i(-1, -1)}

var zone := "restaurant"
var view: ViewState
var edge_void: SceneVoid

func setup(view_state: ViewState) -> void:
	view = view_state
	z_index = -1
	edge_void = SceneVoid.new()
	edge_void.z_index = -4
	add_child(edge_void)

func set_zone(z: String) -> void:
	zone = z
	edge_void.set_zone(z)
	queue_redraw()

func _draw() -> void:
	var g := GameState.grid(zone)
	var lay := GameState.layout_for(zone)
	var vis := _visible_cells(g)
	_draw_ground(g, lay, vis)
	_draw_walls(lay)
	if view != null and view.edit_mode:
		_draw_edit_overlay(g, lay, vis)
	elif view != null and view.ghost_id != "":
		_draw_grid(g, lay, vis)

func _visible_cells(g: WorldGrid) -> Rect2i:
	var rect := get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, get_viewport_rect().size)
	rect = rect.grow(Iso.TILE_W * 2.0 + WALL_H)
	var lo := Vector2i(g.size)
	var hi := Vector2i(-1, -1)
	for corner in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
		var cc := Iso.world_to_cell(corner)
		lo = Vector2i(mini(lo.x, cc.x), mini(lo.y, cc.y))
		hi = Vector2i(maxi(hi.x, cc.x), maxi(hi.y, cc.y))
	lo = lo.clamp(Vector2i.ZERO, g.size - Vector2i.ONE)
	hi = hi.clamp(Vector2i.ZERO, g.size - Vector2i.ONE)
	return Rect2i(lo, hi - lo + Vector2i.ONE)

func _cell_poly(c: Vector2i) -> PackedVector2Array:
	var pts := Iso.footprint_corners(c, Vector2i.ONE)
	var mid := Iso.cell_to_world(c)
	for i in range(4):
		pts[i] += (pts[i] - mid).normalized() * 0.7
	return pts

# One tile of ground art on cell c, if the art for this ground kind exists. Slightly oversized so cells overlap.
func _draw_tile_art(c: Vector2i, t: int) -> bool:
	if not TILE_ART.has(t):
		return false
	var ids: Array = TILE_ART[t]
	var variants: Array = ids.filter(func(id: String) -> bool: return Assets.get_tex(id) != null)
	if variants.is_empty():
		return false
	var pick := int(Noise2D.hash2(c.x, c.y, 71) * variants.size()) % variants.size()
	if t == SceneLayout.Tile.FLOOR:
		pick = (c.x + c.y) % 2 % variants.size()   # the shop floor alternates its two boards like a checker
	var tex := Assets.get_tex(variants[pick])
	var mid := Iso.cell_to_world(c)
	var size := Vector2.ONE * Iso.TILE_W * 1.04
	draw_texture_rect(tex, Rect2(mid - size * 0.5, size), false)
	return true

func ground_color(lay: SceneLayout, g: WorldGrid, c: Vector2i) -> Color:
	var x := c.x
	var y := c.y
	match lay.tile_at(c):
		SceneLayout.Tile.ROAD:
			return ROAD.lerp(ROAD_DARK, Noise2D.hash2(x, y, 61) * 0.5)
		SceneLayout.Tile.PAVEMENT:
			return PAVEMENT.lerp(Color.WHITE, 0.15 * float((x + y) % 2))
		SceneLayout.Tile.FLOOR:
			return FLOOR_A if (x + y) % 2 == 0 else FLOOR_B
		SceneLayout.Tile.SAND:
			return SAND.lerp(Color("d9c286"), Noise2D.hash2(x, y, 62) * 0.5)
		SceneLayout.Tile.DIRT:
			return DIRT.lerp(Color("85663f"), Noise2D.hash2(x, y, 63) * 0.5)
	if g.has_floor(WorldGrid.parcel_of(c)):
		return FLOOR_A if (x + y) % 2 == 0 else FLOOR_B
	return Color(0, 0, 0, 0)

func _draw_ground(g: WorldGrid, lay: SceneLayout, vis: Rect2i) -> void:
	for y in range(vis.position.y, vis.end.y):
		for x in range(vis.position.x, vis.end.x):
			var c := Vector2i(x, y)
			if not lay.is_solid(c):
				continue
			var t := lay.tile_at(c)
			if g.has_floor(WorldGrid.parcel_of(c)) and (t == SceneLayout.Tile.GRASS or t == SceneLayout.Tile.SAND or t == SceneLayout.Tile.DIRT):
				t = SceneLayout.Tile.FLOOR
			if _draw_tile_art(c, t):
				continue
			var col := ground_color(lay, g, c)
			if col.a > 0.0:
				draw_colored_polygon(_cell_poly(c), col)
	_draw_blend(g, lay, vis)

# The ground kind of a cell as far as blending goes: -1 for water and off-map, the floor kind where a floor was built.
func _blend_kind(g: WorldGrid, lay: SceneLayout, c: Vector2i) -> int:
	if not lay.in_bounds(c) or not lay.is_solid(c):
		return -1
	var t := lay.tile_at(c)
	if g.has_floor(WorldGrid.parcel_of(c)) and BLEND_RANK.has(t):
		return SceneLayout.Tile.FLOOR
	return t

func _draw_blend(g: WorldGrid, lay: SceneLayout, vis: Rect2i) -> void:
	var kind_of := func(c: Vector2i) -> int: return _blend_kind(g, lay, c)
	for y in range(vis.position.y, vis.end.y):
		for x in range(vis.position.x, vis.end.x):
			var c := Vector2i(x, y)
			for p in blend_pieces(c, kind_of):
				_draw_blend_piece(c, int(p[0]), str(p[1]))

# The edges and corners laid over cell c, lowest ground kind first: [[kind, "n" | "e" | "s" | "w" | "ne" | "se" | "sw" | "nw"], ...].
# `kind_of` gives the blend kind of any cell. Only SAND and DIRT cells receive pieces, from a neighbour of higher rank.
func blend_pieces(c: Vector2i, kind_of: Callable) -> Array:
	var mine: int = kind_of.call(c)
	if not BLEND_RANK.has(mine) or mine == SceneLayout.Tile.GRASS:
		return []   # only the lower kinds receive an edge (grass is the highest and is drawn by Terrain)
	var rank: int = BLEND_RANK[mine]
	var kinds := {}   # neighbouring kind -> the sides and corners it touches this cell on
	for side in SIDES:
		var k: int = kind_of.call(c + SIDES[side])
		if BLEND_RANK.get(k, 0) > rank:
			kinds[k] = kinds.get(k, []) + [side]
	for corner in CORNERS:
		var d: Vector2i = CORNERS[corner]
		var k: int = kind_of.call(c + d)
		if BLEND_RANK.get(k, 0) <= rank:
			continue
		# the two sides next to this corner already cover it when either one meets that kind
		if int(kind_of.call(c + Vector2i(d.x, 0))) == k or int(kind_of.call(c + Vector2i(0, d.y))) == k:
			continue
		kinds[k] = kinds.get(k, []) + [corner]
	var order: Array = kinds.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return BLEND_RANK[a] < BLEND_RANK[b])
	var out: Array = []
	for k in order:
		for piece in kinds[k]:
			out.append([int(k), str(piece)])
	return out

func _blend_color(kind: int, vx: int, vy: int) -> Color:
	if kind == SceneLayout.Tile.GRASS:
		return Terrain.grass_color(vx, vy)
	return DIRT.lerp(Color("85663f"), Noise2D.hash2(vx, vy, 63) * 0.5)

# One soft edge or corner of `kind` laid over cell c, from art if there is some, else as a gradient.
func _draw_blend_piece(c: Vector2i, kind: int, piece: String) -> void:
	var is_side := SIDES.has(piece)
	var tex := Assets.get_tex("%s_%s_%s_01" % ["edge" if is_side else "corner", BLEND_NAME[kind], piece])
	var mid := Iso.cell_to_world(c)
	if tex != null:
		var size := Vector2.ONE * Iso.TILE_W * 1.04
		draw_texture_rect(tex, Rect2(mid - size * 0.5, size), false)
		return
	# cell corners as vertex coordinates (Terrain colours them): (x, y) is the top-left of cell (x, y)
	var tl := Vector2i(c.x, c.y)
	var depth := BLEND_DEPTH * Iso.TILE_W
	if is_side:
		var v: Array = {"n": [tl, tl + Vector2i(1, 0)], "e": [tl + Vector2i(1, 0), tl + Vector2i(1, 1)],
			"s": [tl + Vector2i(1, 1), tl + Vector2i(0, 1)], "w": [tl + Vector2i(0, 1), tl]}[piece]
		var inward := -Vector2(SIDES[piece]) * depth
		var a := _vertex_point(v[0])
		var b := _vertex_point(v[1])
		var ca := _blend_color(kind, v[0].x, v[0].y)
		var cb := _blend_color(kind, v[1].x, v[1].y)
		draw_polygon(PackedVector2Array([a, b, b + inward, a + inward]), PackedColorArray([ca, cb, Color(cb, 0.0), Color(ca, 0.0)]))
		return
	var d: Vector2i = CORNERS[piece]
	var corner_v := tl + Vector2i((d.x + 1) / 2, (d.y + 1) / 2)
	var p := _vertex_point(corner_v)
	var col := _blend_color(kind, corner_v.x, corner_v.y)
	var inward_x := Vector2(-d.x, 0) * depth
	var inward_y := Vector2(0, -d.y) * depth
	draw_polygon(PackedVector2Array([p, p + inward_x, p + inward_x + inward_y, p + inward_y]),
		PackedColorArray([col, Color(col, 0.0), Color(col, 0.0), Color(col, 0.0)]))

# World point of a vertex (a cell's top-left corner): the same corner Terrain colours.
func _vertex_point(v: Vector2i) -> Vector2:
	return Iso.cell_to_world_f(Vector2(v) - Vector2(0.5, 0.5))

# Cell-corner point in world space.
func _pt(x: float, y: float) -> Vector2:
	return Iso.cell_to_world_f(Vector2(x, y))

func _draw_walls(lay: SceneLayout) -> void:
	var keys: Array = lay.walls.keys()
	# further up the screen first so nearer walls overlap them
	keys.sort_custom(func(a: String, b: String) -> bool:
		var pa: PackedStringArray = a.split(",")
		var pb: PackedStringArray = b.split(",")
		if int(pa[1]) != int(pb[1]):
			return int(pa[1]) < int(pb[1])
		return int(pa[0]) < int(pb[0]))
	for key in keys:
		var p: PackedStringArray = str(key).split(",")
		var x := int(p[0])
		var y := int(p[1])
		var kind := str(lay.walls[key])
		if p[2] == "w":
			_draw_side_wall(lay, x, y, kind)
		else:
			_draw_front_wall(x, y, kind)
		if kind == "door":
			_draw_mat(x, y, p[2] == "w")

# A wall along the top edge of cell (x, y), seen from the front: its face rises from the edge line.
func _draw_front_wall(x: int, y: int, kind: String) -> void:
	var a := _pt(x - 0.5, y - 0.5)
	var h := LOW_H if kind == "low" else WALL_H
	var rect := Rect2(a + Vector2(0, -h), Vector2(Iso.TILE_W, h))
	var base_tex := Assets.get_tex(WALL_ART["low" if kind == "low" else "wall"])
	if base_tex != null:
		draw_texture_rect(base_tex, rect, false)
	else:
		draw_rect(rect, WALL)
		if kind != "low":
			draw_rect(Rect2(a + Vector2(0, -18), Vector2(Iso.TILE_W, 18)), BASEBOARD)
		draw_rect(Rect2(a + Vector2(0, -h), Vector2(Iso.TILE_W, 7 if kind != "low" else 5)), TRIM)
	var overlay := Assets.get_tex(WALL_OVERLAY.get(kind, ""))
	if overlay != null:
		# art anchor: the base line is 24 px (source) above the canvas bottom; a window's base sits 84 px up the wall (above a counter, which is 64 px tall), a door's on the floor line
		var size := overlay.get_size() * (Iso.TILE_W / overlay.get_width())
		var base_y := a.y - (84.0 if kind == "window" else 0.0)
		var drop := 24.0 * Iso.TILE_W / overlay.get_width()
		draw_texture_rect(overlay, Rect2(Vector2(a.x, base_y + drop - size.y), size), false)
	elif kind == "window":
		draw_rect(Rect2(a + Vector2(10, -142), Vector2(44, 56)), WHITE_FRAME)
		draw_rect(Rect2(a + Vector2(14, -138), Vector2(36, 48)), GLASS)
		draw_rect(Rect2(a + Vector2(31, -138), Vector2(2, 48)), WHITE_FRAME)
		draw_rect(Rect2(a + Vector2(14, -116), Vector2(36, 2)), WHITE_FRAME)
	elif kind == "door":
		draw_rect(Rect2(a + Vector2(8, -130), Vector2(48, 132)), TRIM)   # a door is two blocks (128 px) tall
		draw_rect(Rect2(a + Vector2(13, -124), Vector2(38, 126)), Color("5b3a22"))
		draw_circle(a + Vector2(44, -60), 2.5, Color("e8c98a"))

# A wall along the left edge of cell (x, y). Seen from the front it is a thin band; its cap sits a wall height up.
# Consecutive cells of the same kind are drawn as ONE continuous strip, so no seams show between cells.
func _draw_side_wall(lay: SceneLayout, x: int, y: int, kind: String) -> void:
	if kind == "door":
		return   # an opening in a side wall: nothing to see but the mat
	if str(lay.walls.get("%d,%d,w" % [x, y - 1], "")) == kind:
		return   # drawn as part of the run that starts above
	var end_y := y
	while str(lay.walls.get("%d,%d,w" % [x, end_y + 1], "")) == kind:
		end_y += 1
	var a := _pt(x - 0.5, y - 0.5)
	var b := _pt(x - 0.5, end_y + 0.5)
	var h := LOW_H if kind == "low" else WALL_H
	var rect := Rect2(Vector2(a.x - SIDE_W * 0.5, a.y - h), Vector2(SIDE_W, b.y - a.y + h))
	var tex := Assets.get_tex(WALL_SIDE_ART)
	if tex != null and kind != "low":
		var n := end_y - y + 1
		for i in n:
			var yy := b.y - float(n - 1 - i) * Iso.TILE_H
			draw_texture_rect(tex, Rect2(Vector2(a.x - SIDE_W * 0.5, yy - WALL_H), Vector2(SIDE_W, WALL_H)), false)
	else:
		draw_rect(rect, WALL_SIDE)
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 8), Vector2(SIDE_W, 8)), BASEBOARD)
		draw_rect(Rect2(rect.position, Vector2(SIDE_W, 6)), TRIM)

# Door mat laid on the floor next to the doorway.
func _draw_mat(x: int, y: int, side: bool) -> void:
	var o := Vector2(x - 0.5, y - 0.5)
	var r: Rect2
	if side:
		r = Rect2(_pt(o.x + 0.05, o.y + 0.2), Vector2(Iso.TILE_W * 0.55, Iso.TILE_H * 0.6))
	else:
		r = Rect2(_pt(o.x + 0.2, o.y + 0.05), Vector2(Iso.TILE_W * 0.6, Iso.TILE_H * 0.5))
	draw_rect(r, Color("b5483c"))
	draw_rect(r, Color("7c2d26"), false, 2.0)

# Cell lines over the player's land so spots are easy to pick while placing or moving.
func _draw_grid(g: WorldGrid, lay: SceneLayout, vis: Rect2i) -> void:
	for y in range(vis.position.y, vis.end.y):
		for x in range(vis.position.x, vis.end.x):
			var c := Vector2i(x, y)
			if not g.is_owned(c) or not lay.is_solid(c) or lay.is_road(c):
				continue
			var p := Iso.footprint_corners(c, Vector2i.ONE)
			var tint := GRID
			if g.blocked.has(c):
				tint = Color(0.95, 0.4, 0.3, 0.45)
			draw_line(p[0], p[1], tint, 1.4)
			draw_line(p[1], p[2], tint, 1.4)
			draw_line(p[2], p[3], tint, 1.4)
			draw_line(p[3], p[0], tint, 1.4)
			# things snap to half cells: a fainter line through the middle of the cell
			var half := Color(tint, tint.a * 0.5)
			draw_line((p[0] + p[3]) * 0.5, (p[1] + p[2]) * 0.5, half, 1.0)
			draw_line((p[0] + p[1]) * 0.5, (p[3] + p[2]) * 0.5, half, 1.0)

const LAND_TINT := {".": Color(0.5, 0.5, 0.55, 0.28), "B": Color(1.0, 0.85, 0.2, 0.30), "S": Color(0.3, 0.9, 0.4, 0.34)}

# The map editor shows every cell, the land blocks, and with the land tool what each block is.
func _draw_edit_overlay(g: WorldGrid, lay: SceneLayout, vis: Rect2i) -> void:
	for y in range(vis.position.y, vis.end.y):
		for x in range(vis.position.x, vis.end.x):
			var c := Vector2i(x, y)
			var p := Iso.footprint_corners(c, Vector2i.ONE)
			var tint := Color(1, 1, 1, 0.30) if lay.is_solid(c) else Color(1, 1, 1, 0.12)
			draw_line(p[0], p[1], tint, 1.2)
			draw_line(p[3], p[0], tint, 1.2)
			draw_line(p[1], p[2], tint, 1.2)
			draw_line(p[2], p[3], tint, 1.2)
	var psz := Vector2i.ONE * WorldGrid.PARCEL
	var font := ThemeDB.fallback_font
	for py in range(lay.parcels.size()):
		for px in range(lay.parcels[py].length()):
			var corners := Iso.footprint_corners(Vector2i(px, py) * WorldGrid.PARCEL, psz)
			var closed := corners.duplicate()
			closed.append(corners[0])
			draw_polyline(closed, Color(1, 1, 1, 0.55), 2.4)
			if view.edit_tool == "land":
				var label := lay.label_of_parcel(Vector2i(px, py))
				draw_colored_polygon(corners, LAND_TINT.get(label, LAND_TINT["."]))
				var mid := Iso.footprint_center(Vector2i(px, py) * WorldGrid.PARCEL, psz)
				var text: String = {".": "-", "B": "$", "S": "S"}.get(label, "?")
				draw_string(font, mid + Vector2(-9, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
