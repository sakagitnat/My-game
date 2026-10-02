class_name SceneDecor
extends Node2D

# Drawn from a scene's SceneLayout and the player's land (GameState): the ground kinds the owner painted
# (road, pavement, floor, sand, dirt), floor built over bought land, the walls on cell edges, and the build grid
# shown while placing or moving. Reads only. Colours and shapes are code-drawn stand-ins until art arrives.
const WALL_H := 118.0
const LOW_H := 15.0
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
	if view != null and view.ghost_id != "":
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
			var col := ground_color(lay, g, c)
			if col.a > 0.0:
				draw_colored_polygon(_cell_poly(c), col)

# Cell-corner point in world space, lifted by `up` pixels.
func _pt(x: float, y: float, up: float = 0.0) -> Vector2:
	return Iso.cell_to_world_f(Vector2(x, y)) + Vector2(0, -up)

func _quad(a: Vector2, b: Vector2, up_a: float, up_b: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, -up_b), a + Vector2(0, -up_a)]), col)

# A rectangle on a wall between fractions t0..t1 along it and h0..h1 of its height.
func _wall_rect(a: Vector2, b: Vector2, t0: float, t1: float, h0: float, h1: float, col: Color) -> void:
	var p0 := a.lerp(b, t0)
	var p1 := a.lerp(b, t1)
	draw_colored_polygon(PackedVector2Array([p0 + Vector2(0, -WALL_H * h0), p1 + Vector2(0, -WALL_H * h0), p1 + Vector2(0, -WALL_H * h1), p0 + Vector2(0, -WALL_H * h1)]), col)

func _draw_walls(lay: SceneLayout) -> void:
	var keys: Array = lay.walls.keys()
	# far ones first so nearer walls overlap them
	keys.sort_custom(func(a: String, b: String) -> bool:
		var pa: PackedStringArray = a.split(",")
		var pb: PackedStringArray = b.split(",")
		return int(pa[0]) + int(pa[1]) < int(pb[0]) + int(pb[1]))
	for key in keys:
		var p: PackedStringArray = str(key).split(",")
		var x := int(p[0])
		var y := int(p[1])
		var a: Vector2
		var b: Vector2
		var side: bool = p[2] == "w"
		if side:
			a = _pt(x - 0.5, y - 0.5)
			b = _pt(x - 0.5, y + 0.5)
		else:
			a = _pt(x - 0.5, y - 0.5)
			b = _pt(x + 0.5, y - 0.5)
		_draw_wall_piece(a, b, str(lay.walls[key]), side)
		if lay.walls[key] == "door":
			_draw_mat(x, y, side)

func _draw_wall_piece(a: Vector2, b: Vector2, kind: String, side: bool) -> void:
	var body := WALL_SIDE if side else WALL
	match kind:
		"low":
			_quad(a, b, LOW_H, LOW_H, body)
			draw_line(a + Vector2(0, -LOW_H), b + Vector2(0, -LOW_H), TRIM, 2.0)
		"door":
			# an opening: frame posts and a lintel
			_wall_rect(a, b, 0.0, 0.1, 0.0, 0.8, TRIM)
			_wall_rect(a, b, 0.9, 1.0, 0.0, 0.8, TRIM)
			_wall_rect(a, b, 0.0, 1.0, 0.8, 1.0, body)
			draw_line(a + Vector2(0, -WALL_H * 0.8), b + Vector2(0, -WALL_H * 0.8), TRIM, 3.0)
		_:
			_quad(a, b, WALL_H, WALL_H, body)
			_quad(a, b, 18.0, 18.0, BASEBOARD)
			if kind == "window":
				_wall_rect(a, b, 0.08, 0.92, 0.3, 0.84, WHITE_FRAME)
				_wall_rect(a, b, 0.14, 0.86, 0.34, 0.8, GLASS)
				_wall_rect(a, b, 0.49, 0.51, 0.34, 0.8, WHITE_FRAME)
			draw_line(a + Vector2(0, -WALL_H), b + Vector2(0, -WALL_H), TRIM, 4.0)
	if kind == "low" or kind == "door":
		var h := LOW_H if kind == "low" else WALL_H
		draw_line(a, a + Vector2(0, -h), TRIM, 3.0)
		draw_line(b, b + Vector2(0, -h), TRIM, 3.0)

# Door mat on the cell the door opens onto (south of a north-edge door, east of a west-edge one).
func _draw_mat(x: int, y: int, side: bool) -> void:
	var o := Vector2(x - 0.5, y - 0.5)
	var pts := PackedVector2Array()
	if side:
		pts = PackedVector2Array([_pt(o.x, o.y + 0.15), _pt(o.x + 0.9, o.y + 0.15), _pt(o.x + 0.9, o.y + 0.85), _pt(o.x, o.y + 0.85)])
	else:
		pts = PackedVector2Array([_pt(o.x + 0.15, o.y), _pt(o.x + 0.85, o.y), _pt(o.x + 0.85, o.y + 0.9), _pt(o.x + 0.15, o.y + 0.9)])
	draw_colored_polygon(pts, Color("b5483c"))
	pts.append(pts[0])
	draw_polyline(pts, Color("7c2d26"), 2.0)

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
