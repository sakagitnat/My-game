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
	for shader_path in ["res://shaders/sunlight.gdshader", "res://shaders/vignette.gdshader"]:
		var r := ColorRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = load(shader_path)
		r.material = m
		light_layer.add_child(r)

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
		items.append([o.x + o.y + fp.x + fp.y, 0, o])
	for c in g.blocked:
		items.append([c.x + c.y + 1, 1, c])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for it in items:
		if it[1] == 0:
			_draw_object(it[2], g.objects[it[2]])
		else:
			_draw_obstacle(it[2], g.blocked[it[2]])
	if view.selected_origin != NONE and g.objects.has(view.selected_origin):
		var pts := Iso.footprint_corners(view.selected_origin, g.footprints[view.selected_origin])
		pts.append(pts[0])
		draw_polyline(pts, Color.WHITE, 3.0)
	if view.selected_obstacle != NONE:
		var pts := Iso.footprint_corners(view.selected_obstacle, Vector2i.ONE)
		pts.append(pts[0])
		draw_polyline(pts, Color.WHITE, 3.0)
	if view.ghost_id != "":
		_draw_ghost()

func _draw_shadow(center: Vector2, rx: float) -> void:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * i / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * rx * 0.5))
	draw_colored_polygon(pts, Color(0.05, 0.14, 0.05, 0.28))

func _draw_obstacle(c: Vector2i, kind: String) -> void:
	var art := ArtCatalog.obstacle(kind)
	var p := Iso.cell_to_world(c)
	var foot := p + Vector2(0, Iso.TILE_H * 0.5)
	_draw_shadow(p + Vector2(0, 6), Iso.TILE_W * 0.34 * float(art.scale))
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
	var sz: Vector2i = Catalog.size_of(view.ghost_id)
	var origin := GameState.footprint_origin(view.ghost_cell, sz)
	var pts := Iso.footprint_corners(origin, sz)
	var tint := Color(0.4, 0.9, 0.4, 0.45) if ok else Color(0.95, 0.3, 0.25, 0.45)
	draw_colored_polygon(pts, tint)
	var edge := pts.duplicate()
	edge.append(pts[0])
	draw_polyline(edge, Color(tint, 1.0), 3.0)
	var def: Dictionary = Catalog.PLACEABLES[view.ghost_id]
	if def.get("flat", false):
		return
	if not _draw_sprite(view.ghost_id, origin, sz, Color(1, 1, 1, 0.75)):
		_draw_box(origin, sz, Color(ArtCatalog.placeable_color(view.ghost_id), 0.75))

# Floor-style art: the canvas width maps to `width`, the diamond is centred in the canvas.
func _draw_flat_art(id: String, center: Vector2, width: float, tint: Color = Color.WHITE) -> bool:
	var tex := Assets.get_tex(id)
	if tex == null:
		return false
	var s := tex.get_size() * (width / tex.get_width())
	draw_texture_rect(tex, Rect2(center - s * 0.5, s), false, tint)
	return true

# Upright art: the canvas width maps to the footprint width and its bottom edge sits on the footprint's bottom corner.
func _draw_sprite(id: String, origin: Vector2i, sz: Vector2i, tint: Color = Color.WHITE) -> bool:
	var tex := Assets.get_tex(id)
	if tex == null:
		return false
	var s := tex.get_size() * (Iso.footprint_width(sz) / tex.get_width())
	var foot := Iso.footprint_center(origin, sz) + Vector2(0, Iso.footprint_height(sz) * 0.5)
	draw_texture_rect(tex, Rect2(foot - Vector2(s.x * 0.5, s.y), s), false, tint)
	return true

func _object_height(sz: Vector2i) -> float:
	return 9.5 * (sz.x + sz.y)

func _draw_object(origin: Vector2i, id: String) -> void:
	var def: Dictionary = Catalog.PLACEABLES[id]
	var sz: Vector2i = def.size
	if def.get("flat", false):
		_draw_plot(origin, sz)
		return
	_draw_shadow(Iso.footprint_center(origin, sz) + Vector2(0, Iso.footprint_height(sz) * 0.18), Iso.footprint_width(sz) * 0.42)
	if not _draw_sprite(id, origin, sz):
		_draw_box(origin, sz, ArtCatalog.placeable_color(id))
	_draw_status(origin, sz, _object_height(sz))

func _draw_box(origin: Vector2i, sz: Vector2i, col: Color) -> void:
	var k := Iso.footprint_corners(origin, sz)
	var up := Vector2(0, -_object_height(sz))
	var top := k[0]
	var right := k[1]
	var bottom := k[2]
	var left := k[3]
	draw_colored_polygon(PackedVector2Array([left, bottom, bottom + up, left + up]), col.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([bottom, right, right + up, bottom + up]), col.darkened(0.45))
	var lid := PackedVector2Array([left + up, top + up, right + up, bottom + up])
	draw_colored_polygon(lid, col)
	lid.append(lid[0])
	draw_polyline(lid, col.darkened(0.35), 1.5)

func _draw_plot(origin: Vector2i, sz: Vector2i) -> void:
	var g := GameState.grid(view.zone)
	var center := Iso.footprint_center(origin, sz)
	var prog := GameState.progress(view.zone, origin)
	var wet := prog >= 0.0
	if not _draw_flat_art("tile_soil_wet_01" if wet else "tile_soil_dry_01", center, Iso.footprint_width(sz)):
		var pts := Iso.footprint_corners(origin, sz)
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
	var top := Iso.footprint_corners(origin, sz)[0] + Vector2(0, -height - 12.0)
	if prog >= 1.0:
		draw_circle(top, 11, Color("2b1d12"))
		draw_circle(top, 8, Color("ffd66b"))
		return
	draw_rect(Rect2(top + Vector2(-22, -3), Vector2(44, 7)), Color("2b1d12"))
	draw_rect(Rect2(top + Vector2(-21, -2), Vector2(42.0 * prog, 5)), Color("8fe06a"))
