extends Node2D

const TAP_SLOP := 12.0
const ZOOM_MIN := 0.35
const ZOOM_MAX := 2.2
const REDRAW_EVERY := 0.5
const START_VIEW_WIDTH := 1000.0
const NONE := WorldGrid.NONE

var zone: String = "restaurant"
var camera: Camera2D
var hud: Hud
var terrain: Terrain
var signs: Terrain
var coast: Node2D
var sea: ColorRect

# Placement mode: choosing a spot for a new item (placing_id) or for an existing one (moving_origin).
var placing_id: String = ""
var moving_origin: Vector2i = NONE
var ghost_cell: Vector2i = Vector2i.ZERO
var selected_origin: Vector2i = NONE
var selected_obstacle: Vector2i = NONE
var redraw_timer: float = 0.0
var context_timer: float = 0.0

var pressing := false
var dragged := false
var press_pos := Vector2.ZERO
var touches: Dictionary = {}
var pinch_dist := 0.0
var pinched := false

func _ready() -> void:
	camera = Camera2D.new()
	add_child(camera)
	_build_backdrop()
	hud = Hud.new()
	add_child(hud)
	hud.zone_toggled.connect(func() -> void: set_zone("farm" if zone == "restaurant" else "restaurant"))
	hud.item_picked.connect(start_placement)
	hud.crop_chosen.connect(_on_crop_chosen)
	hud.action_pressed.connect(_on_action_pressed)
	hud.move_requested.connect(_on_move_requested)
	hud.sell_requested.connect(_on_sell_requested)
	hud.placement_confirmed.connect(confirm_placement)
	hud.placement_cancelled.connect(cancel_placement)
	hud.reset_confirmed.connect(_on_reset)
	GameState.changed.connect(_on_state_changed)
	GameState.leveled_up.connect(_on_leveled_up)
	Loc.changed.connect(_on_state_changed)
	set_zone("restaurant")

# ---------------------------------------------------------------- backdrop

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
	coast = load("res://scripts/world/coast.gd").new()
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

func _redraw_all() -> void:
	queue_redraw()
	if terrain != null:
		terrain.queue_redraw()
		signs.queue_redraw()

# ---------------------------------------------------------------- zones & state

func set_zone(z: String) -> void:
	zone = z
	cancel_placement()
	_deselect()
	hud.close_modal()
	hud.set_zone(z)
	terrain.set_zone(z)
	signs.set_zone(z)
	camera.position = Iso.cell_to_world(GameState.start_cell())
	camera.zoom = Vector2.ONE * clampf(get_viewport_rect().size.x / START_VIEW_WIDTH, 0.6, 1.4)
	hud.show_message("HINT_FARM" if z == "farm" else "HINT_START")
	_redraw_all()

func _on_state_changed() -> void:
	hud.refresh()
	if selected_origin != NONE:
		if GameState.grid(zone).objects.has(selected_origin):
			hud.show_context(_context_info(selected_origin))
		else:
			_deselect()
	if selected_obstacle != NONE:
		if GameState.grid(zone).blocked.has(selected_obstacle):
			hud.show_context(_obstacle_info(selected_obstacle))
		else:
			_deselect()
	if placing_id != "":
		_update_placement_ui()
	_redraw_all()

func _on_leveled_up(new_level: int) -> void:
	hud.show_message("MSG_LEVEL_UP", [new_level, GameState.level_up_reward(new_level)])
	hud.float_text(Loc.t("LEVEL_FMT") % new_level, get_viewport_rect().size * Vector2(0.5, 0.35), UiTheme.GOLD)

func _on_reset() -> void:
	GameState.reset()
	GameState.save_game()
	set_zone("restaurant")
	GameState.changed.emit()

func _fmt_time(seconds: int) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), seconds % 60]

func _screen_of(world_pos: Vector2) -> Vector2:
	return get_canvas_transform() * world_pos

# [message key, argument] for a failed placement code.
func _error_text(code: String, item_id: String = "") -> Array:
	match code:
		"no_coins": return ["MSG_NO_COINS", null]
		"locked": return ["MSG_LOCKED", null]
		"occupied": return ["MSG_OCCUPIED", null]
		"blocked": return ["MSG_BLOCKED", null]
		"level": return ["MSG_LEVEL", Catalog.unlock_level(item_id) if item_id != "" else null]
	return ["MSG_INVALID", null]

# ---------------------------------------------------------------- placement mode

func start_placement(id: String) -> void:
	_deselect()
	placing_id = id
	moving_origin = NONE
	ghost_cell = Iso.world_to_cell(camera.position)
	_update_placement_ui()
	_redraw_all()

func start_move(origin: Vector2i) -> void:
	var g := GameState.grid(zone)
	if not g.objects.has(origin):
		return
	_deselect()
	placing_id = g.objects[origin]
	moving_origin = origin
	var sz: Vector2i = g.footprints[origin]
	ghost_cell = origin + Vector2i(floori((sz.x - 1) / 2.0), floori((sz.y - 1) / 2.0))
	_update_placement_ui()
	_redraw_all()

func set_ghost(c: Vector2i) -> void:
	ghost_cell = c
	_update_placement_ui()
	_redraw_all()

func placement_status() -> String:
	if placing_id == "":
		return ""
	if moving_origin != NONE:
		return GameState.check_move(zone, moving_origin, ghost_cell)
	return GameState.check_place(zone, ghost_cell, placing_id)

func _update_placement_ui() -> void:
	var st := placement_status()
	var def: Dictionary = Catalog.PLACEABLES[placing_id]
	var detail := Loc.t("PLACE_HINT")
	if st == "ok":
		if moving_origin == NONE:
			detail = str(GameState.place_cost(placing_id))
	else:
		var e := _error_text(st, placing_id)
		detail = Loc.t(e[0]) % e[1] if e[1] != null else Loc.t(e[0])
	hud.show_placement("%s\n%s" % [Loc.t(def.name), detail], st == "ok", moving_origin != NONE)

func confirm_placement() -> void:
	if placing_id == "":
		return
	var st := placement_status()
	if st != "ok":
		var e := _error_text(st, placing_id)
		hud.show_message(e[0], e[1])
		return
	if moving_origin != NONE:
		GameState.move_object(zone, moving_origin, ghost_cell)
		cancel_placement()
		hud.show_message("MSG_MOVED")
		return
	var cost := GameState.place_cost(placing_id)
	var at := Iso.cell_to_world(ghost_cell)
	GameState.place_object(zone, ghost_cell, placing_id)
	hud.float_text("-%d" % cost, _screen_of(at), UiTheme.BAD)
	hud.show_message("MSG_PLACED")
	# Step the ghost along so rows of plots or fences go down quickly.
	set_ghost(ghost_cell + Vector2i(Catalog.size_of(placing_id).x, 0))

func cancel_placement() -> void:
	placing_id = ""
	moving_origin = NONE
	if hud != null:
		hud.hide_placement()
	_redraw_all()

# ---------------------------------------------------------------- selecting & interacting

func _deselect() -> void:
	selected_origin = NONE
	selected_obstacle = NONE
	if hud != null:
		hud.hide_context()
	_redraw_all()

func _on_tap(world: Vector2) -> void:
	var c := Iso.world_to_cell(world)
	var g := GameState.grid(zone)
	if placing_id != "":
		if g.in_bounds(c):
			set_ghost(c)
		return
	if not g.in_bounds(c):
		_deselect()
		return
	var origin := g.origin_at(c)
	if origin != NONE:
		_select(origin)
		return
	if g.blocked.has(c) and g.is_owned(c):
		_select_obstacle(c)
		return
	_deselect()
	if not g.is_owned(c) and g.can_buy_parcel(WorldGrid.parcel_of(c)):
		_ask_buy(c)

func _ask_buy(c: Vector2i) -> void:
	var cost := GameState.land_cost(zone)
	hud.ask_confirm(Loc.t("CONFIRM_BUY_LAND") % cost, _buy_land.bind(c, cost))

func _buy_land(c: Vector2i, cost: int) -> void:
	var result := GameState.buy_land(zone, c)
	if result == "ok":
		hud.show_message("MSG_BOUGHT", cost)
	elif result == "no_coins":
		hud.show_message("MSG_NO_COINS")
	else:
		hud.show_message("MSG_INVALID")

func _select(origin: Vector2i) -> void:
	selected_origin = origin
	var id: String = GameState.grid(zone).objects[origin]
	if (id == "farm_plot_01" or id == "farm_coop_01") and GameState.progress(zone, origin) >= 1.0:
		_do_interact(origin, "")
		_deselect()
		return
	hud.show_context(_context_info(origin))
	_redraw_all()

func _select_obstacle(c: Vector2i) -> void:
	_deselect()
	selected_obstacle = c
	hud.show_context(_obstacle_info(c))
	_redraw_all()

func _obstacle_info(c: Vector2i) -> Dictionary:
	var def: Dictionary = Catalog.OBSTACLES[GameState.grid(zone).blocked[c]]
	return {
		"title": Loc.t(def.name),
		"status": Loc.t("STATUS_OBSTACLE"),
		"plain": true,
		"action": {"text": Loc.t("BTN_CLEAR") % int(def.cost), "enabled": GameState.coins >= int(def.cost)},
	}

func _context_info(origin: Vector2i) -> Dictionary:
	var g := GameState.grid(zone)
	var id: String = g.objects[origin]
	var def: Dictionary = Catalog.PLACEABLES[id]
	var info := {"title": Loc.t(def.name), "status": "", "sell": GameState.refund_for(zone, origin)}
	var prog := GameState.progress(zone, origin)
	if id == "farm_plot_01":
		if prog < 0.0:
			info.status = Loc.t("STATUS_EMPTY")
			var crops: Array = []
			for crop in Catalog.CROPS:
				var cd: Dictionary = Catalog.CROPS[crop]
				var locked := GameState.level < int(cd.level)
				var free_wheat: bool = crop == "wheat" and GameState.is_broke()
				crops.append({
					"id": crop,
					"text": (Loc.t("LOCKED_LV") % cd.level) if locked else "%s\n%d" % [Loc.t(cd.name), cd.seed],
					"enabled": not locked and (GameState.coins >= int(cd.seed) or free_wheat)})
			info.crops = crops
		else:
			info.status = Loc.t("STATUS_GROWING") % _fmt_time(GameState.seconds_left(zone, origin))
	elif id == "farm_coop_01":
		if prog < 0.0:
			info.status = Loc.t("STATUS_COOP_IDLE")
			info.action = {"text": Loc.t("BTN_FEED"), "enabled": GameState.inventory.count(Catalog.COOP.feed) > 0}
		else:
			info.status = Loc.t("STATUS_COOP_BUSY") % _fmt_time(GameState.seconds_left(zone, origin))
	return info

func _on_crop_chosen(crop: String) -> void:
	if selected_origin == NONE:
		return
	var origin := selected_origin
	_do_interact(origin, crop)
	_deselect()

func _on_action_pressed() -> void:
	if selected_obstacle != NONE:
		_clear_selected_obstacle()
		return
	if selected_origin == NONE:
		return
	var origin := selected_origin
	_do_interact(origin, "")
	_deselect()

func _clear_selected_obstacle() -> void:
	var c := selected_obstacle
	var kind: String = GameState.grid(zone).blocked.get(c, "")
	if kind == "":
		_deselect()
		return
	var def: Dictionary = Catalog.OBSTACLES[kind]
	var at := _screen_of(Iso.cell_to_world(c))
	match GameState.clear_obstacle(zone, c):
		"ok":
			hud.show_message("MSG_CLEARED")
			hud.float_text(Loc.t("FLOAT_XP") % int(def.xp), at, UiTheme.GOLD)
			if def.item != "":
				hud.float_text(Loc.t("FLOAT_GAIN") % [1, Loc.t(Catalog.ITEMS[def.item].name)], at + Vector2(0, 32), UiTheme.GOOD)
		"no_coins": hud.show_message("MSG_NO_COINS")
		_: hud.show_message("MSG_INVALID")
	_deselect()

func _do_interact(origin: Vector2i, seed_id: String) -> void:
	var g := GameState.grid(zone)
	var crop: String = g.states.get(origin, {}).get("crop", "")
	var at := _screen_of(Iso.footprint_center(origin, g.footprints[origin]))
	var result := GameState.interact(zone, origin, seed_id)
	match result:
		"planted": hud.show_message("MSG_PLANTED")
		"harvested":
			hud.show_message("MSG_HARVESTED")
			hud.float_text(Loc.t("FLOAT_GAIN") % [1, Loc.t(Catalog.CROPS[crop].name)], at, UiTheme.GOOD)
			hud.float_text(Loc.t("FLOAT_XP") % int(Catalog.CROPS[crop].xp), at + Vector2(0, 32), UiTheme.GOLD)
		"fed": hud.show_message("MSG_FED")
		"collected":
			hud.show_message("MSG_COLLECTED")
			hud.float_text(Loc.t("FLOAT_GAIN") % [1, Loc.t("ITEM_EGG")], at, UiTheme.GOOD)
			hud.float_text(Loc.t("FLOAT_XP") % int(Catalog.COOP.xp), at + Vector2(0, 32), UiTheme.GOLD)
		"growing": hud.show_message("MSG_GROWING", _fmt_time(GameState.seconds_left(zone, origin)))
		"busy": hud.show_message("MSG_BUSY", _fmt_time(GameState.seconds_left(zone, origin)))
		"no_coins": hud.show_message("MSG_NO_COINS")
		"no_feed": hud.show_message("MSG_NO_FEED")
		"full": hud.show_message("MSG_FULL")
		"level": hud.show_message("MSG_LEVEL", int(Catalog.CROPS[seed_id].level) if Catalog.CROPS.has(seed_id) else 1)
		_: hud.show_message("MSG_INVALID")

func _on_move_requested() -> void:
	if selected_origin != NONE:
		start_move(selected_origin)

func _on_sell_requested() -> void:
	if selected_origin == NONE:
		return
	var origin := selected_origin
	var g := GameState.grid(zone)
	var refund := GameState.refund_for(zone, origin)
	var has_crop: bool = g.states.has(origin) and g.objects[origin] == "farm_plot_01"
	var text := Loc.t("CONFIRM_SELL_CROP" if has_crop else "CONFIRM_SELL") % refund
	hud.ask_confirm(text, func() -> void:
		if GameState.remove_object(zone, origin) == "ok":
			hud.show_message("MSG_REMOVED", refund))

# ---------------------------------------------------------------- frame & input

func _process(delta: float) -> void:
	_update_sea()
	if selected_obstacle != NONE and hud.context.visible:
		hud.place_context(_screen_of(Iso.cell_to_world(selected_obstacle) + Vector2(0, -50)))
	if zone == "farm":
		redraw_timer += delta
		if redraw_timer >= REDRAW_EVERY:
			redraw_timer = 0.0
			queue_redraw()
	if selected_origin != NONE and hud.context.visible:
		var g := GameState.grid(zone)
		if g.objects.has(selected_origin):
			var top := Iso.footprint_corners(selected_origin, g.footprints[selected_origin])[0]
			hud.place_context(_screen_of(top))
		context_timer += delta
		if context_timer >= 1.0:
			context_timer = 0.0
			if g.objects.has(selected_origin):
				hud.show_context(_context_info(selected_origin))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
			pinch_dist = 0.0
		if touches.size() >= 2:
			pinched = true
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() == 2:
			var pts: Array = touches.values()
			var d: float = pts[0].distance_to(pts[1])
			if pinch_dist > 0.0 and d > 0.0:
				_zoom_by(d / pinch_dist)
			pinch_dist = d
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressing = true
				dragged = false
				press_pos = event.position
				if touches.is_empty():
					pinched = false
			else:
				if pressing and not dragged and not pinched:
					_on_tap(get_global_mouse_position())
				pressing = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / 1.1)
	elif event is InputEventMouseMotion and pressing and not pinched:
		if not dragged and event.position.distance_to(press_pos) > TAP_SLOP:
			dragged = true
		if dragged:
			camera.position -= event.relative / camera.zoom.x
			_clamp_camera()

func _zoom_by(f: float) -> void:
	var z := clampf(camera.zoom.x * f, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(z, z)
	_redraw_all()

func _clamp_camera() -> void:
	var s := GameState.GRID_SIZE
	var lo := Vector2(Iso.cell_to_world(Vector2i(0, s.y)).x, 0.0)
	var hi := Vector2(Iso.cell_to_world(Vector2i(s.x, 0)).x, Iso.cell_to_world(s).y)
	camera.position = camera.position.clamp(lo, hi)
	_redraw_all()

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var g := GameState.grid(zone)
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
	if selected_origin != NONE and g.objects.has(selected_origin):
		var pts := Iso.footprint_corners(selected_origin, g.footprints[selected_origin])
		pts.append(pts[0])
		draw_polyline(pts, Color.WHITE, 3.0)
	if selected_obstacle != NONE:
		var pts := Iso.footprint_corners(selected_obstacle, Vector2i.ONE)
		pts.append(pts[0])
		draw_polyline(pts, Color.WHITE, 3.0)
	if placing_id != "":
		_draw_ghost()

func _draw_shadow(center: Vector2, rx: float) -> void:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * i / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * rx * 0.5))
	draw_colored_polygon(pts, Color(0.05, 0.14, 0.05, 0.28))

func _draw_obstacle(c: Vector2i, kind: String) -> void:
	var def: Dictionary = Catalog.OBSTACLES[kind]
	var p := Iso.cell_to_world(c)
	var foot := p + Vector2(0, Iso.TILE_H * 0.5)
	_draw_shadow(p + Vector2(0, 6), Iso.TILE_W * 0.34 * float(def.scale))
	var tex := Assets.get_tex(def.art)
	if tex != null:
		var s := tex.get_size() * (Iso.TILE_W * float(def.scale) / tex.get_width())
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
	var ok := placement_status() == "ok"
	var sz: Vector2i = Catalog.size_of(placing_id)
	var origin := GameState.footprint_origin(ghost_cell, sz)
	var pts := Iso.footprint_corners(origin, sz)
	var tint := Color(0.4, 0.9, 0.4, 0.45) if ok else Color(0.95, 0.3, 0.25, 0.45)
	draw_colored_polygon(pts, tint)
	var edge := pts.duplicate()
	edge.append(pts[0])
	draw_polyline(edge, Color(tint, 1.0), 3.0)
	var def: Dictionary = Catalog.PLACEABLES[placing_id]
	if def.get("flat", false):
		return
	if not _draw_sprite(placing_id, origin, sz, Color(1, 1, 1, 0.75)):
		_draw_box(origin, sz, Color(def.color, 0.75))

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
		_draw_box(origin, sz, def.color)
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
	var g := GameState.grid(zone)
	var center := Iso.footprint_center(origin, sz)
	var prog := GameState.progress(zone, origin)
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
	var ripe: Color = Catalog.CROPS[crop].color
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
	var prog := GameState.progress(zone, origin)
	if prog < 0.0:
		return
	var top := Iso.footprint_corners(origin, sz)[0] + Vector2(0, -height - 12.0)
	if prog >= 1.0:
		draw_circle(top, 11, Color("2b1d12"))
		draw_circle(top, 8, Color("ffd66b"))
		return
	draw_rect(Rect2(top + Vector2(-22, -3), Vector2(44, 7)), Color("2b1d12"))
	draw_rect(Rect2(top + Vector2(-21, -2), Vector2(42.0 * prog, 5)), Color("8fe06a"))
