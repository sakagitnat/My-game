class_name Terrain
extends Node2D

# Continuous ground: every cell corner gets a colour from smooth noise, so neighbouring
# cells blend with no seams. Also draws the beach, grass tufts, stone walls and sale signs.
const GRASS_DARK := Color("5fa838")
const GRASS_LIGHT := Color("94d856")
const SAND_DARK := Color("d6bb7f")
const SAND_LIGHT := Color("f0deac")
const DRY := Color("cdb860")
const STONE := Color("b9bcc0")
const WALL_STEP := 11.0

var zone: String = "island"
# "ground" draws the terrain; a second instance with "signs" sits above objects so prices stay readable.
var layer: String = "ground"
var _colors: Dictionary = {}

func set_zone(z: String) -> void:
	zone = z
	_colors.clear()
	queue_redraw()

# d: whole cells from this corner to the water (0 on the shoreline itself).
func _color_at(vx: int, vy: int, d: float) -> Color:
	var n := Noise2D.value(vx * 0.15, vy * 0.15, 11)
	var m := Noise2D.value(vx * 0.65, vy * 0.65, 23)
	var t := clampf(n * 0.75 + m * 0.25, 0.0, 1.0)
	var grass := GRASS_DARK.lerp(GRASS_LIGHT, t)
	var beach := clampf((2.6 - d) / 1.8, 0.0, 1.0)
	return grass.lerp(SAND_DARK.lerp(SAND_LIGHT, m), beach)

func _corner_color(vx: int, vy: int) -> Color:
	var key := vx * 1000 + vy
	if _colors.has(key):
		return _colors[key]
	var col := _color_at(vx, vy, maxf(0.0, GameState.layout.vertex_distance(vx, vy) - 0.5))
	_colors[key] = col
	return col

# The land part of a cell on the shore: the quad cut where the coast field crosses zero (Sutherland-Hodgman),
# with sand colour on the cut so the beach follows the real shoreline.
func _shore_cell(x: int, y: int, dry: bool) -> Array:
	var lay := GameState.layout
	var gp: Array[Vector2] = [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]
	var fv: Array[float] = [lay.vertex_field(x, y), lay.vertex_field(x + 1, y), lay.vertex_field(x + 1, y + 1), lay.vertex_field(x, y + 1)]
	var cv: Array[Color] = [_corner_color(x, y), _corner_color(x + 1, y), _corner_color(x + 1, y + 1), _corner_color(x, y + 1)]
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in range(4):
		var j := (i + 1) % 4
		if fv[i] > 0.0:
			pts.append(gp[i])
			cols.append(cv[i])
		if (fv[i] > 0.0) != (fv[j] > 0.0):
			var t := fv[i] / (fv[i] - fv[j])
			pts.append(gp[i].lerp(gp[j], t))
			cols.append(_color_at(x, y, 0.0))
	var world := PackedVector2Array()
	for p in pts:
		world.append(Iso.cell_to_world_f(p - Vector2(0.5, 0.5)))
	# A sliver (two corners of the cut almost on top of each other) cannot be filled; skip it.
	var area := 0.0
	for i in range(world.size()):
		var a := world[i]
		var b := world[(i + 1) % world.size()]
		area += a.x * b.y - b.x * a.y
	if world.size() < 3 or absf(area) < 6.0:
		return [PackedVector2Array(), PackedColorArray()]
	if dry:
		for i in range(cols.size()):
			cols[i] = cols[i].lerp(DRY, 0.16)
	return [world, cols]

func _visible_cells(g: WorldGrid) -> Rect2i:
	var view := get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, get_viewport_rect().size)
	view = view.grow(Iso.TILE_W * 2.0)
	var lo := Vector2i(g.size)
	var hi := Vector2i(-1, -1)
	for corner in [view.position, view.end, Vector2(view.position.x, view.end.y), Vector2(view.end.x, view.position.y)]:
		var cc := Iso.world_to_cell(corner)
		lo = Vector2i(mini(lo.x, cc.x), mini(lo.y, cc.y))
		hi = Vector2i(maxi(hi.x, cc.x), maxi(hi.y, cc.y))
	lo = lo.clamp(Vector2i.ZERO, g.size - Vector2i.ONE)
	hi = hi.clamp(Vector2i.ZERO, g.size - Vector2i.ONE)
	return Rect2i(lo, hi - lo + Vector2i.ONE)

func _draw() -> void:
	var g := GameState.grid(zone)
	if layer == "signs":
		_draw_for_sale(g, true)
		return
	var vis := _visible_cells(g)
	for y in range(vis.position.y, vis.end.y):
		for x in range(vis.position.x, vis.end.x):
			var c := Vector2i(x, y)
			if not GameState.layout.has_land(c):
				continue
			if not GameState.layout.is_solid(c):
				var part := _shore_cell(x, y, not g.is_owned(c))
				if part[0].size() >= 3:
					draw_polygon(part[0], part[1])
				continue
			var pts := Iso.footprint_corners(c, Vector2i.ONE)
			var mid := Iso.cell_to_world(c)
			for i in range(4):
				pts[i] += (pts[i] - mid).normalized() * 0.7
			var cols := PackedColorArray([_corner_color(x, y), _corner_color(x + 1, y), _corner_color(x + 1, y + 1), _corner_color(x, y + 1)])
			if not g.is_owned(c):
				for i in range(4):
					cols[i] = cols[i].lerp(DRY, 0.16)
			draw_polygon(pts, cols)
	_draw_decor(g, vis)
	_draw_for_sale(g, false)

func _draw_decor(g: WorldGrid, vis: Rect2i) -> void:
	for y in range(vis.position.y, vis.end.y):
		for x in range(vis.position.x, vis.end.x):
			var c := Vector2i(x, y)
			if GameState.edge_distance(c) < 3 or g.occupied.has(c) or g.blocked.has(c):
				continue
			var h := Noise2D.hash2(x, y, 5)
			if h > 0.13:
				continue
			var p := Iso.cell_to_world(c) + Vector2(Noise2D.hash2(x, y, 6) - 0.5, Noise2D.hash2(x, y, 7) - 0.5) * 30.0
			if h < 0.025:
				var petal := Color("fff2a8") if Noise2D.hash2(x, y, 8) < 0.5 else Color("ffffff")
				for k in range(5):
					draw_circle(p + Vector2.from_angle(k * TAU / 5.0) * 2.6, 1.9, petal)
				draw_circle(p, 1.6, Color("f0a020"))
			else:
				var col := Color("4d9630")
				for k in range(3):
					var bx := p.x + (k - 1) * 3.0
					draw_line(Vector2(bx, p.y), Vector2(bx + (k - 1) * 2.0, p.y - 6.0 - k % 2 * 2.0), col, 1.6)

func _draw_for_sale(g: WorldGrid, signs: bool) -> void:
	var psize := Vector2i.ONE * WorldGrid.PARCEL
	var font := ThemeDB.fallback_font
	for py in range(g.parcel_grid().y):
		for px in range(g.parcel_grid().x):
			var parcel := Vector2i(px, py)
			if not g.can_buy_parcel(parcel):
				continue
			var origin := parcel * WorldGrid.PARCEL
			if signs:
				_draw_sign(Iso.footprint_center(origin, psize), str(GameState.land_cost(zone)), font)
				continue
			var k := Iso.footprint_corners(origin, psize)
			for i in range(4):
				_draw_wall(k[i], k[(i + 1) % 4], origin.x * 7 + origin.y * 13 + i)

func _draw_wall(a: Vector2, b: Vector2, seed_v: int) -> void:
	var n := maxi(2, int(a.distance_to(b) / WALL_STEP))
	for i in range(n + 1):
		var p := a.lerp(b, float(i) / n)
		var jx := Noise2D.hash2(i, seed_v, 3) - 0.5
		var jy := Noise2D.hash2(i, seed_v, 4) - 0.5
		p += Vector2(jx, jy) * 3.0
		if not GameState.layout.is_solid(Iso.world_to_cell(p)):
			continue
		var r := 4.6 + Noise2D.hash2(i, seed_v, 9) * 2.2
		draw_circle(p + Vector2(1.2, 2.2), r, Color(0, 0, 0, 0.25))
		draw_circle(p, r, STONE.darkened(0.12 + 0.1 * Noise2D.hash2(i, seed_v, 10)))
		draw_circle(p + Vector2(-1.2, -1.6), r * 0.62, STONE.lightened(0.18))

func _draw_sign(center: Vector2, price: String, font: Font) -> void:
	var post_top := center + Vector2(0, -34)
	draw_line(center + Vector2(0, 4), post_top, Color("6b4a2c"), 4.0)
	draw_circle(center + Vector2(0, 5), 7, Color(0, 0, 0, 0.22))
	var board := Rect2(post_top + Vector2(-46, -36), Vector2(92, 42))
	draw_rect(Rect2(board.position + Vector2(2, 3), board.size), Color(0, 0, 0, 0.25))
	draw_rect(board, Color("8a5a32"))
	draw_rect(board.grow(-3), Color("e8c98a"))
	draw_circle(board.position + Vector2(18, 21), 9, Color("a8761f"))
	draw_circle(board.position + Vector2(18, 21), 7, Color("ffd66b"))
	draw_string(font, board.position + Vector2(30, 29), price, HORIZONTAL_ALIGNMENT_LEFT, 58, 22, Color("3a2412"))
