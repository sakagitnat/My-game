extends Node2D

const TAP_SLOP := 12.0
const ZOOM_MIN := 0.35
const ZOOM_MAX := 2.2

var zone: String = "restaurant"
var tool: String = "buy"
var camera: Camera2D
var coins_label: Label
var zone_buttons: Dictionary = {}
var lang_button: Button
var tool_bar: HBoxContainer
var tool_buttons: Dictionary = {}
var message_label: Label
var message_key: String = "HINT_START"
var message_arg = null
var message_time: float = 0.0

var pressing := false
var dragged := false
var press_pos := Vector2.ZERO
var touches: Dictionary = {}
var pinch_dist := 0.0
var pinched := false

func _ready() -> void:
	camera = Camera2D.new()
	add_child(camera)
	_build_ui()
	GameState.changed.connect(_on_state_changed)
	Loc.changed.connect(_refresh_text)
	set_zone("restaurant")

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	top.add_theme_constant_override("separation", 12)
	ui.add_child(top)
	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", 28)
	coins_label.custom_minimum_size = Vector2(190, 64)
	coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(coins_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	for z in Catalog.ZONES:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(160, 64)
		b.pressed.connect(set_zone.bind(z))
		top.add_child(b)
		zone_buttons[z] = b
	lang_button = Button.new()
	lang_button.custom_minimum_size = Vector2(120, 64)
	lang_button.pressed.connect(Loc.toggle)
	top.add_child(lang_button)

	message_label = Label.new()
	_anchor_bottom(message_label, 190, 120)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 8)
	ui.add_child(message_label)

	tool_bar = HBoxContainer.new()
	_anchor_bottom(tool_bar, 104, 16)
	tool_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tool_bar.add_theme_constant_override("separation", 12)
	ui.add_child(tool_bar)

func _anchor_bottom(c: Control, top_margin: float, bottom_margin: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 16
	c.offset_right = -16
	c.offset_top = -top_margin
	c.offset_bottom = -bottom_margin

func set_zone(z: String) -> void:
	zone = z
	tool = "buy"
	for k in zone_buttons:
		zone_buttons[k].button_pressed = (k == z)
	for child in tool_bar.get_children():
		child.queue_free()
	tool_buttons.clear()
	var group := ButtonGroup.new()
	var ids: Array[String] = ["buy"]
	ids.append_array(Catalog.placeables_for(z))
	ids.append("remove")
	for id in ids:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(150, 72)
		b.button_pressed = (id == "buy")
		b.pressed.connect(_select_tool.bind(id))
		tool_bar.add_child(b)
		tool_buttons[id] = b
	camera.position = Iso.cell_to_world(Vector2i(GameState.GRID_SIZE / 2))
	camera.zoom = Vector2.ONE * 0.8
	_refresh_text()
	queue_redraw()

func _select_tool(id: String) -> void:
	tool = id
	_refresh_text()

func _tool_label(id: String) -> String:
	match id:
		"buy":
			return "%s\n%d" % [Loc.t("TOOL_BUY"), GameState.land_cost(zone)]
		"remove":
			return Loc.t("TOOL_REMOVE")
	var def: Dictionary = Catalog.PLACEABLES[id]
	return "%s\n%d" % [Loc.t(def.name), def.cost]

func _refresh_text() -> void:
	coins_label.text = Loc.t("HUD_COINS") % GameState.coins
	zone_buttons["restaurant"].text = Loc.t("ZONE_RESTAURANT")
	zone_buttons["farm"].text = Loc.t("ZONE_FARM")
	lang_button.text = Loc.t("LANG_BUTTON")
	for id in tool_buttons:
		tool_buttons[id].text = _tool_label(id)
	var msg := Loc.t(message_key)
	message_label.text = msg % message_arg if message_arg != null else msg

func _on_state_changed() -> void:
	_refresh_text()
	queue_redraw()

func show_message(key: String, arg = null) -> void:
	message_key = key
	message_arg = arg
	message_time = 4.0
	_refresh_text()

func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		message_label.modulate.a = clampf(message_time, 0.0, 1.0)

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

func _clamp_camera() -> void:
	var s := GameState.GRID_SIZE
	var lo := Vector2(Iso.cell_to_world(Vector2i(0, s.y)).x, 0.0)
	var hi := Vector2(Iso.cell_to_world(Vector2i(s.x, 0)).x, Iso.cell_to_world(s).y)
	camera.position = camera.position.clamp(lo, hi)

func _on_tap(world: Vector2) -> void:
	var c := Iso.world_to_cell(world)
	var g := GameState.grid(zone)
	if not g.in_bounds(c):
		return
	var result := ""
	var paid := 0
	if tool == "buy":
		paid = GameState.land_cost(zone)
		result = GameState.buy_land(zone, c)
	elif tool == "remove":
		paid = GameState.refund_for(zone, c)
		result = GameState.remove_object(zone, c)
	else:
		result = GameState.place_object(zone, c, tool)
	match result:
		"ok":
			if tool == "buy":
				show_message("MSG_BOUGHT", paid)
			elif tool == "remove":
				show_message("MSG_REMOVED", paid)
			else:
				show_message("MSG_PLACED")
		"no_coins": show_message("MSG_NO_COINS")
		"locked": show_message("MSG_LOCKED")
		"occupied": show_message("MSG_OCCUPIED")
		"empty": show_message("MSG_EMPTY")
		_: show_message("MSG_INVALID")

func _draw() -> void:
	var g := GameState.grid(zone)
	var font := ThemeDB.fallback_font
	for y in range(g.size.y):
		for x in range(g.size.x):
			var c := Vector2i(x, y)
			var p := Iso.cell_to_world(c)
			if g.is_owned(c):
				_draw_floor(Catalog.FLOOR[zone], p, Catalog.FLOOR_COLOR[zone])
			else:
				_draw_floor(Catalog.LOCKED_TILE, p, Color("2f3a33"))
				if g.can_buy(c):
					_outline(p, Color("ffd66b"))
					draw_string(font, p + Vector2(-32, 8), str(GameState.land_cost(zone)),
						HORIZONTAL_ALIGNMENT_CENTER, 64, 22, Color("ffd66b"))
	var cells: Array = g.objects.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x + a.y < b.x + b.y)
	for c in cells:
		_draw_object(g.objects[c], Iso.cell_to_world(c))

func _diamond(p: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(0, -hh), p + Vector2(hw, 0), p + Vector2(0, hh), p + Vector2(-hw, 0)])

func _outline(p: Vector2, col: Color) -> void:
	var pts := _diamond(p, Iso.TILE_W * 0.5 - 2, Iso.TILE_H * 0.5 - 1)
	pts.append(pts[0])
	draw_polyline(pts, col, 3.0)

func _draw_floor(id: String, p: Vector2, fallback: Color) -> void:
	var tex := Assets.get_tex(id)
	if tex != null:
		var s := tex.get_size() * Assets.ART_SCALE
		draw_texture_rect(tex, Rect2(p - s * 0.5, s), false)
		return
	draw_colored_polygon(_diamond(p, Iso.TILE_W * 0.5, Iso.TILE_H * 0.5), fallback)
	var pts := _diamond(p, Iso.TILE_W * 0.5, Iso.TILE_H * 0.5)
	pts.append(pts[0])
	draw_polyline(pts, fallback.darkened(0.25), 1.5)

func _draw_object(id: String, p: Vector2) -> void:
	var tex := Assets.get_tex(id)
	if tex != null:
		var s := tex.get_size() * Assets.ART_SCALE
		var foot := p + Vector2(0, Iso.TILE_H * 0.5)
		draw_texture_rect(tex, Rect2(foot - Vector2(s.x * 0.5, s.y), s), false)
		return
	var col: Color = Catalog.PLACEABLES[id].color
	var hw := 44.0
	var hh := 22.0
	var h := Vector2(0, -38)
	var l := p + Vector2(-hw, 0)
	var r := p + Vector2(hw, 0)
	var b := p + Vector2(0, hh)
	var t := p + Vector2(0, -hh)
	draw_colored_polygon(PackedVector2Array([l, b, b + h, l + h]), col.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([b, r, r + h, b + h]), col.darkened(0.45))
	draw_colored_polygon(PackedVector2Array([l + h, t + h, r + h, b + h]), col)
