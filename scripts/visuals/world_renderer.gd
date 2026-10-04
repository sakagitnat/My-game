class_name WorldRenderer
extends Node2D

# Everything the player sees of the world: sea, terrain, objects, obstacles, ghost, light.
# Reads GameState/WorldGrid/Catalog and the ViewState only. Never changes game state.
# Owned by the graphics side (docs/COLLAB.md); world.gd calls setup(), set_zone() and refresh().
const NONE := WorldGrid.NONE
const REDRAW_EVERY := 0.5

var view: ViewState
var camera: Camera2D
var terrain: Terrain
var signs: Terrain
var coast: Node2D
var sea: ColorRect
var _timer := 0.0
var _sun_timer: float = 0.0
var daylight: ShaderMaterial   # the time-of-day tint (shaders/daylight.gdshader)

func setup(view_state: ViewState, cam: Camera2D) -> void:
	view = view_state
	camera = cam
	_build_backdrop()

func set_zone(z: String) -> void:
	terrain.set_zone(z)
	signs.set_zone(z)
	coast.set_zone(z)
	refresh()

# Called when game state, selection, camera or zoom changed.
func refresh() -> void:
	queue_redraw()
	if terrain != null:
		terrain.queue_redraw()
		signs.queue_redraw()

func _process(delta: float) -> void:
	if sea == null:
		return
	_update_sea()
	# the light follows the time of day (white while editing the map, so what is painted can be judged)
	daylight.set_shader_parameter("tint", Color.WHITE if view.edit_mode else GameState.day_clock.tint())
	# shadows lean and shorten with the sun: redraw about once a second
	_sun_timer += delta
	if _sun_timer >= 1.0:
		_sun_timer = 0.0
		queue_redraw()
	# Growth bars and ready markers change with time even when nothing else does.
	if not GameState.grid(view.zone).states.is_empty():
		_timer += delta
		if _timer >= REDRAW_EVERY:
			_timer = 0.0
			queue_redraw()

func _build_backdrop() -> void:
	var sea_layer := CanvasLayer.new()
	sea_layer.layer = -10
	add_child(sea_layer)
	sea = ColorRect.new()
	sea.set_anchors_preset(Control.PRESET_FULL_RECT)
	sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sea.gdshader")
	sea.material = mat
	sea_layer.add_child(sea)
	terrain = Terrain.new()
	terrain.z_index = -2
	add_child(terrain)
	coast = load("res://scripts/visuals/coast.gd").new()
	coast.z_index = -1
	add_child(coast)
	signs = Terrain.new()
	signs.layer = "signs"
	signs.z_index = 1
	add_child(signs)
	var light_layer := CanvasLayer.new()
	light_layer.layer = 5
	add_child(light_layer)
	for shader_path in ["res://shaders/sunlight.gdshader", "res://shaders/daylight.gdshader", "res://shaders/vignette.gdshader"]:
		var r := ColorRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = load(shader_path)
		r.material = m
		light_layer.add_child(r)
		if shader_path.ends_with("daylight.gdshader"):
			daylight = m

func _update_sea() -> void:
	var m := sea.material as ShaderMaterial
	m.set_shader_parameter("cam_pos", camera.position)
	m.set_shader_parameter("zoom", camera.zoom.x)
	m.set_shader_parameter("view_size", get_viewport_rect().size)

func _draw() -> void:
	var g := GameState.grid(view.zone)
	var items: Array = []
	for o in g.objects:
		var fp: Vector2i = g.footprints[o]
		items.append([Iso.footprint_depth(o, fp), 0, o])
	for c in g.blocked:
		items.append([Iso.depth_key(Vector2(c.x * Iso.SUB, (c.y + 1) * Iso.SUB)), 1, c])
	for t in g.tops:
		# drawn right after the table it stands on, so the table never covers it
		var table: Vector2i = g.occupied.get(t, t)
		var tfp: Vector2i = g.footprints.get(table, Vector2i.ONE)
		items.append([Iso.depth_key(Vector2(float(table.x) + 0.1 + float(t.y) * 0.001 + float(t.x) * 0.00001, float(table.y + tfp.y))), 2, t])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for it in items:
		if it[1] == 0:
			_draw_object(it[2], g.objects[it[2]])
		elif it[1] == 2:
			_draw_top(it[2], g.tops[it[2]])
		else:
			_draw_obstacle(it[2], g.blocked[it[2]])
	var sel_dict := g.tops if view.selected_top else g.objects
	if view.selected_origin != NONE and sel_dict.has(view.selected_origin):
		var pts := Iso.unit_corners(view.selected_origin, (g.top_footprints if view.selected_top else g.footprints)[view.selected_origin])
		pts.append(pts[0])
		draw_polyline(pts, Color.WHITE, 3.0)
	if view.selected_obstacle != NONE:
		var pts := Iso.footprint_corners(view.selected_obstacle, Vector2i.ONE)
		pts.append(pts[0])
		draw_polyline(pts, Color.WHITE, 3.0)
	if view.ghost_id != "":
		_draw_ghost()

# Soft ellipse under a thing. It leans away from the sun (right in the morning, left in the evening), is long at dawn and
# dusk, short and darker at noon and faint at night (DayClock.sun).
func _draw_shadow(center: Vector2, rx: float) -> void:
	var sun := GameState.day_clock.sun()
	var rl := rx * float(sun.length)
	var c := center + Vector2(float(sun.dir) * rx * 0.55, 0.0)
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rl, sin(a) * rl * 0.5))
	draw_colored_polygon(pts, Color(0.05, 0.14, 0.05, float(sun.alpha)))

func _draw_obstacle(c: Vector2i, kind: String) -> void:
	var art := ArtCatalog.obstacle_look(kind, Noise2D.hash2(c.x, c.y, 41), func(id: String) -> bool: return Assets.get_tex(id) != null)
	var p := Iso.cell_to_world(c)
	var foot := p + Vector2(0, Iso.TILE_H * 0.5)
	_draw_shadow(foot + Vector2(0, -6), Iso.TILE_W * 0.2 * float(art.scale) + 4.0)
	var tex := Assets.get_tex(art.art)
	if tex != null:
		var s := tex.get_size() * (Iso.TILE_W * float(art.scale) / tex.get_width())
		draw_texture_rect(tex, Rect2(foot - Vector2(s.x * 0.5, s.y), s), false)
		return
	var wob := 0.5 + Noise2D.hash2(c.x, c.y, 31) * 0.5
	match kind:
		"tree":
			draw_rect(Rect2(foot + Vector2(-3.5, -30), Vector2(7, 30)), Color("6b4a2c"))
			draw_circle(foot + Vector2(0, -56), 21 * wob + 6, Color("2f7a2a"))
			draw_circle(foot + Vector2(-13, -42), 15, Color("2f7a2a"))
			draw_circle(foot + Vector2(13, -42), 15, Color("2f7a2a"))
			draw_circle(foot + Vector2(-5, -60), 13, Color("49a83c"))
			draw_circle(foot + Vector2(8, -50), 9, Color("5cbd4a"))
		"rock":
			var r := PackedVector2Array([foot + Vector2(-16, -2), foot + Vector2(-12, -14), foot + Vector2(-2, -20), foot + Vector2(11, -15), foot + Vector2(17, -3), foot + Vector2(0, 3)])
			draw_colored_polygon(r, Color("8a8f96"))
			draw_colored_polygon(PackedVector2Array([r[1], r[2], r[3], foot + Vector2(0, -8)]), Color("b4b9c0"))
		_:
			draw_circle(foot + Vector2(-8, -9), 10, Color("3b8c34"))
			draw_circle(foot + Vector2(8, -8), 9, Color("3b8c34"))
			draw_circle(foot + Vector2(0, -15), 10, Color("55a846"))

func _draw_ghost() -> void:
	var ok := view.ghost_status == "ok"
	var facing := view.ghost_facing
	var sz: Vector2i = Catalog.size_facing(view.ghost_id, facing)
	var origin := GameState.footprint_origin(view.ghost_cell, sz)
	var pts := Iso.unit_corners(origin, sz)
	var tint := Color(0.4, 0.9, 0.4, 0.45) if ok else Color(0.95, 0.3, 0.25, 0.45)
	if Catalog.is_top(view.ghost_id):
		# a thing for a table hovers at table height (over whatever table is under it, else at the usual height)
		draw_set_transform(Vector2(0, _surface_offset(GameState.grid(view.zone), origin, sz, -ArtCatalog.HOVER)))
	draw_colored_polygon(pts, tint)
	var edge := pts.duplicate()
	edge.append(pts[0])
	draw_polyline(edge, Color(tint, 1.0), 3.0)
	var def: Dictionary = Catalog.PLACEABLES[view.ghost_id]
	if def.get("flat", false):
		return
	var fa := ArtCatalog.facing_art(view.ghost_id, facing)
	if not _draw_facing_sprite(view.ghost_id, fa, origin, sz, Color(1, 1, 1, 0.75)):
		_draw_box(origin, sz, Color(ArtCatalog.placeable_color(view.ghost_id), 0.75), facing if Catalog.is_rotatable(view.ghost_id) else -1, ArtCatalog.height_blocks(view.ghost_id))
	draw_set_transform(Vector2.ZERO)

# Floor-style art: the canvas width maps to `width` and the canvas is centred on `center`.
func _draw_flat_art(id: String, center: Vector2, width: float, tint: Color = Color.WHITE) -> bool:
	var tex := Assets.get_tex(id)
	if tex == null:
		return false
	var s := tex.get_size() * (width / tex.get_width())
	draw_texture_rect(tex, Rect2(center - s * 0.5, s), false, tint)
	return true

# Upright art: the canvas width maps to the footprint width and its bottom edge sits on the footprint's bottom edge.
func _draw_sprite(id: String, origin: Vector2i, sz: Vector2i, tint: Color = Color.WHITE, flip: bool = false) -> bool:
	var tex := Assets.get_tex(id)
	if tex == null:
		return false
	var foot := Iso.unit_center(origin, sz) + Vector2(0, Iso.unit_height(sz) * 0.5)
	# art anchor: the middle of the bottom edge of the picture sits on the middle of the bottom edge of the footprint (the foot);
	# an ArtCatalog.ART_BOX entry can make the picture wider than the footprint or move it
	var rect := ArtCatalog.sprite_rect(ArtCatalog.art_box(id), tex.get_size(), foot, Iso.unit_width(sz))
	if flip:
		rect = Rect2(rect.position + Vector2(rect.size.x, 0.0), Vector2(-rect.size.x, rect.size.y))
	draw_texture_rect(tex, rect, false, tint)
	return true


# The picture for a turn; when that turn's own picture is not there yet, the thing's front picture is used (not a stand-in box).
func _draw_facing_sprite(id: String, fa: Dictionary, origin: Vector2i, sz: Vector2i, tint: Color) -> bool:
	return _draw_sprite(fa.art, origin, sz, tint, fa.flip) or (fa.art != id and _draw_sprite(id, origin, sz, tint))

func _draw_object(origin: Vector2i, id: String) -> void:
	var def: Dictionary = Catalog.PLACEABLES[id]
	var g := GameState.grid(view.zone)
	var sz: Vector2i = g.footprints.get(origin, def.size)
	var facing := g.facing_at(origin)
	if def.get("flat", false):
		_draw_plot(origin, sz)
		return
	_draw_shadow(Iso.unit_center(origin, sz) + Vector2(0, Iso.unit_height(sz) * 0.32), Iso.unit_width(sz) * 0.42)
	var fa := ArtCatalog.facing_art(id, facing)
	if not _draw_facing_sprite(id, fa, origin, sz, Color.WHITE):
		_draw_box(origin, sz, ArtCatalog.placeable_color(id), facing if Catalog.is_rotatable(id) else -1, ArtCatalog.height_blocks(id))
	_draw_status(origin, sz, Iso.TILE_H * ArtCatalog.height_blocks(id))

# `facing` >= 0 marks the front of the stand-in with a dark band (0 front face, 1 left, 2 back/top, 3 right).
# How far up the screen, in pixels, a small thing of footprint `sz` at `origin` must be drawn to stand on the table under it:
# its foot goes on the table's top band, the further back on the table the higher up. `fallback` when there is no table.
func _surface_offset(g: WorldGrid, origin: Vector2i, sz: Vector2i, fallback: float) -> float:
	var table: Vector2i = g.occupied.get(origin + Vector2i(0, sz.y - 1), WorldGrid.NONE)
	if table == WorldGrid.NONE:
		return fallback
	var tfp: Vector2i = g.footprints[table]
	var band := ArtCatalog.surface_band(str(g.objects[table]))
	var depth := clampf((origin.y + sz.y - table.y) / float(tfp.y), 0.0, 1.0)
	var foot_y := Iso.unit_corner(table).y + (band.x + depth * (band.y - band.x)) * Iso.unit_height(tfp)
	return foot_y - (Iso.unit_corner(origin).y + Iso.unit_height(sz))

# A small thing standing on a table: drawn like an upright object, moved up onto the table top.
func _draw_top(origin: Vector2i, id: String) -> void:
	var g := GameState.grid(view.zone)
	var sz: Vector2i = g.top_footprints[origin]
	draw_set_transform(Vector2(0, _surface_offset(g, origin, sz, 0.0)))
	_draw_shadow(Iso.unit_center(origin, sz) + Vector2(0, Iso.unit_height(sz) * 0.3), Iso.unit_width(sz) * 0.4)
	var fa := ArtCatalog.facing_art(id, 0)
	if not _draw_sprite(fa.art, origin, sz, Color.WHITE, fa.flip):
		_draw_box(origin, sz, ArtCatalog.placeable_color(id), -1, ArtCatalog.height_blocks(id))
	draw_set_transform(Vector2.ZERO)

func _draw_box(origin: Vector2i, sz: Vector2i, col: Color, facing: int = -1, blocks: float = 1.0) -> void:
	# A stand-in seen from the front and a little from above: a front face under a shorter top face.
	var k := Iso.unit_corners(origin, sz)
	var h := Iso.TILE_H * blocks   # a block is one cell tall
	var depth := Iso.unit_height(sz) * 0.5
	var bl := k[3]
	var br := k[2]
	var front := PackedVector2Array([bl + Vector2(0, -h), br + Vector2(0, -h), br, bl])
	draw_colored_polygon(front, col.darkened(0.25))
	var top := PackedVector2Array([bl + Vector2(0, -h - depth), br + Vector2(0, -h - depth), br + Vector2(0, -h), bl + Vector2(0, -h)])
	draw_colored_polygon(top, col)
	var mark := col.darkened(0.55)
	match facing:
		0:
			draw_colored_polygon(PackedVector2Array([bl + Vector2(0, -h * 0.3), br + Vector2(0, -h * 0.3), br, bl]), mark)
		1:
			draw_colored_polygon(PackedVector2Array([bl + Vector2(0, -h), bl + Vector2(8, -h), bl + Vector2(8, 0), bl]), mark)
		2:
			draw_colored_polygon(PackedVector2Array([bl + Vector2(0, -h - depth), br + Vector2(0, -h - depth), br + Vector2(0, -h - depth + 8), bl + Vector2(0, -h - depth + 8)]), mark)
		3:
			draw_colored_polygon(PackedVector2Array([br + Vector2(-8, -h), br + Vector2(0, -h), br, br + Vector2(-8, 0)]), mark)
	top.append(top[0])
	draw_polyline(top, col.darkened(0.35), 1.5)

func _draw_plot(origin: Vector2i, sz: Vector2i) -> void:
	var g := GameState.grid(view.zone)
	var center := Iso.unit_center(origin, sz)
	var prog := GameState.progress(view.zone, origin)
	var wet := prog >= 0.0
	if not _draw_flat_art("tile_soil_wet_01" if wet else "tile_soil_dry_01", center, Iso.unit_width(sz)):
		var pts := Iso.unit_corners(origin, sz)
		draw_colored_polygon(pts, Color("4c331e") if wet else Color("7a5535"))
		pts.append(pts[0])
		draw_polyline(pts, Color("2b1d12"), 1.5)
	if wet:
		var crop: String = g.states[origin].crop
		if not _draw_sprite("crop_%s_s%d" % [crop, Catalog.crop_stage(prog)], origin, sz):
			_draw_crop_placeholder(crop, prog, center)
	_draw_status(origin, sz, 0.0)

func _draw_crop_placeholder(crop: String, prog: float, p: Vector2) -> void:
	var stage := Catalog.crop_stage(prog)
	var ripe: Color = ArtCatalog.crop_color(crop)
	var green := Color("5aa845")
	var col := green
	if stage == 3:
		col = green.lerp(ripe, 0.5)
	elif stage == 4:
		col = ripe
	var r: float = [4.0, 7.0, 10.0, 13.0][stage - 1]
	for off in [Vector2(-20, -2), Vector2(0, 8), Vector2(20, -2), Vector2(0, -10)]:
		draw_circle(p + off + Vector2(0, -r * 0.5), r, col)

func _draw_status(origin: Vector2i, sz: Vector2i, height: float) -> void:
	var prog := GameState.progress(view.zone, origin)
	if prog < 0.0:
		return
	var corners := Iso.unit_corners(origin, sz)
	var top := (corners[0] + corners[1]) * 0.5 + Vector2(0, -height - 12.0)
	if prog >= 1.0:
		draw_circle(top, 11, Color("2b1d12"))
		draw_circle(top, 8, Color("ffd66b"))
		return
	draw_rect(Rect2(top + Vector2(-22, -3), Vector2(44, 7)), Color("2b1d12"))
	draw_rect(Rect2(top + Vector2(-21, -2), Vector2(42.0 * prog, 5)), Color("8fe06a"))
