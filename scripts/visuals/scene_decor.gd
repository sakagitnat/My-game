class_name SceneDecor
extends Node2D

# Drawn from a scene's SceneLayout and the player's land (GameState): the country road, the paved strip at the
# door, indoor floor on the blocks built over, the shop walls with their windows, and the build grid shown while
# the player is placing or moving something. Reads only. Colours are code-drawn stand-ins until art arrives.
const WALL_H := 118.0
const SILL_H := 15.0
const FLOOR_A := Color("ead3a8")
const FLOOR_B := Color("d9bb8b")
const ROAD := Color("b79a6a")
const ROAD_DARK := Color("a58a5c")
const PAVEMENT := Color("d6cdb9")
const WALL := Color("f3e4c4")
const WALL_SIDE := Color("e3d0a8")
const BASEBOARD := Color("a3714a")
const TRIM := Color("7a5233")
const GLASS := Color("bfe3f2")
const GRID := Color(1, 1, 1, 0.34)
const WHITE_FRAME := Color("fffaf0")

var zone := "restaurant"
var view: ViewState

func setup(view_state: ViewState) -> void:
	view = view_state
	z_index = -1

func set_zone(z: String) -> void:
	zone = z
	queue_redraw()

func _draw() -> void:
	var g := GameState.grid(zone)
	var lay := GameState.layout_for(zone)
	var vis := _visible_cells(g)
	_draw_ground(g, lay, vis)
	if lay.shell.has_area():
		_draw_shell(lay)
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

func _draw_ground(g: WorldGrid, lay: SceneLayout, vis: Rect2i) -> void:
	for y in range(vis.position.y, vis.end.y):
		for x in range(vis.position.x, vis.end.x):
			var c := Vector2i(x, y)
			if lay.road.has_point(c):
				var col := ROAD.lerp(ROAD_DARK, Noise2D.hash2(x, y, 61) * 0.5 + (0.25 if y == lay.road.position.y + 1 or y == lay.road.end.y - 2 else 0.0))
				draw_colored_polygon(_cell_poly(c), col)
			elif lay.pavement.has_point(c):
				draw_colored_polygon(_cell_poly(c), PAVEMENT.lerp(Color.WHITE, 0.15 * float((x + y) % 2)))
			elif g.has_floor(WorldGrid.parcel_of(c)) and lay.is_solid(c):
				draw_colored_polygon(_cell_poly(c), FLOOR_A if (x + y) % 2 == 0 else FLOOR_B)

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

func _draw_window(a: Vector2, b: Vector2, t0: float, t1: float) -> void:
	_wall_rect(a, b, t0 - 0.012, t1 + 0.012, 0.3, 0.84, WHITE_FRAME)
	_wall_rect(a, b, t0, t1, 0.34, 0.8, GLASS)
	var mid := (t0 + t1) * 0.5
	_wall_rect(a, b, mid - 0.006, mid + 0.006, 0.34, 0.8, WHITE_FRAME)
	_wall_rect(a, b, t0, t1, 0.565, 0.575, WHITE_FRAME)

func _draw_shell(lay: SceneLayout) -> void:
	var r := lay.shell
	var x0 := r.position.x - 0.5
	var y0 := r.position.y - 0.5
	var x1 := r.end.x - 0.5
	var y1 := r.end.y - 0.5
	var tl := _pt(x0, y0)
	var tr := _pt(x1, y0)
	var br := _pt(x1, y1)
	var bl := _pt(x0, y1)
	# back wall facing the sea (top-right edge) and back wall on the left (top-left edge)
	_quad(tl, tr, WALL_H, WALL_H, WALL)
	_quad(tl, bl, WALL_H, WALL_H, WALL_SIDE)
	_quad(tl, tr, 18.0, 18.0, BASEBOARD)
	_quad(tl, bl, 18.0, 18.0, BASEBOARD.darkened(0.12))
	for w in [[0.1, 0.3], [0.38, 0.62], [0.7, 0.9]]:
		_draw_window(tl, tr, w[0], w[1])
	for w in [[0.2, 0.42], [0.58, 0.8]]:
		_draw_window(tl, bl, w[0], w[1])
	draw_line(tl + Vector2(0, -WALL_H), tr + Vector2(0, -WALL_H), TRIM, 4.0)
	draw_line(tl + Vector2(0, -WALL_H), bl + Vector2(0, -WALL_H), TRIM, 4.0)
	draw_line(tl, tl + Vector2(0, -WALL_H), TRIM, 4.0)
	# low sills along the open sides; the front one leaves a gap for the door
	_quad(tr, br, SILL_H, SILL_H, WALL_SIDE)
	var door_lo := 9999.0
	var door_hi := -9999.0
	for d in lay.door_cells:
		door_lo = minf(door_lo, d.x - 0.5)
		door_hi = maxf(door_hi, d.x + 0.5)
	if door_hi < door_lo:
		_quad(bl, br, SILL_H, SILL_H, WALL)
	else:
		_quad(bl, _pt(door_lo, y1), SILL_H, SILL_H, WALL)
		_quad(_pt(door_hi, y1), br, SILL_H, SILL_H, WALL)
		var mat := PackedVector2Array([_pt(door_lo, y1), _pt(door_hi, y1), _pt(door_hi, y1 + 1.0), _pt(door_lo, y1 + 1.0)])
		draw_colored_polygon(mat, Color("b5483c"))
		mat.append(mat[0])
		draw_polyline(mat, Color("7c2d26"), 2.0)

# Cell lines over the player's land so spots are easy to pick while placing or moving.
func _draw_grid(g: WorldGrid, lay: SceneLayout, vis: Rect2i) -> void:
	for y in range(vis.position.y, vis.end.y):
		for x in range(vis.position.x, vis.end.x):
			var c := Vector2i(x, y)
			if not g.is_owned(c) or not lay.is_solid(c) or lay.road.has_point(c):
				continue
			var p := Iso.footprint_corners(c, Vector2i.ONE)
			var tint := GRID
			if g.blocked.has(c):
				tint = Color(0.95, 0.4, 0.3, 0.45)
			draw_line(p[0], p[1], tint, 1.4)
			draw_line(p[1], p[2], tint, 1.4)
			draw_line(p[2], p[3], tint, 1.4)
			draw_line(p[3], p[0], tint, 1.4)
