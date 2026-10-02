extends Node2D

const TAP_SLOP := 12.0
const ZOOM_MIN := 0.35
const ZOOM_MAX := 2.2
const REDRAW_EVERY := 0.5
const SEED_PREFIX := "seed:"
const START_VIEW_WIDTH := 1000.0

var zone: String = "restaurant"
var tool: String = "buy"
var camera: Camera2D
var coins_label: Label
var barn_button: Button
var zone_buttons: Dictionary = {}
var lang_button: Button
var tool_bar: HBoxContainer
var tool_buttons: Dictionary = {}
var message_label: Label
var message_key: String = "HINT_START"
var message_arg = null
var message_time: float = 0.0
var redraw_timer: float = 0.0
var barn_panel: PanelContainer
var barn_rows: VBoxContainer

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
	Loc.changed.connect(_on_language_changed)
	set_zone("restaurant")

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	top.add_theme_constant_override("separation", 12)
	ui.add_child(top)
	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", 26)
	coins_label.custom_minimum_size = Vector2(150, 64)
	coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(coins_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	barn_button = Button.new()
	barn_button.custom_minimum_size = Vector2(140, 64)
	barn_button.pressed.connect(_toggle_barn)
	top.add_child(barn_button)
	for z in Catalog.ZONES:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(130, 64)
		b.pressed.connect(set_zone.bind(z))
		top.add_child(b)
		zone_buttons[z] = b
	lang_button = Button.new()
	lang_button.custom_minimum_size = Vector2(110, 64)
	lang_button.pressed.connect(Loc.toggle)
	top.add_child(lang_button)

	message_label = Label.new()
	_anchor_bottom(message_label, 190, 120)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 8)
	ui.add_child(message_label)

	var scroll := ScrollContainer.new()
	_anchor_bottom(scroll, 104, 16)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.add_child(scroll)
	tool_bar = HBoxContainer.new()
	tool_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tool_bar.add_theme_constant_override("separation", 10)
	scroll.add_child(tool_bar)

	barn_panel = PanelContainer.new()
	barn_panel.visible = false
	barn_panel.set_anchors_preset(Control.PRESET_CENTER)
	barn_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	barn_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	barn_panel.custom_minimum_size = Vector2(460, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1b2428")
	box.border_color = Color("c58a50")
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(18)
	barn_panel.add_theme_stylebox_override("panel", box)
	barn_rows = VBoxContainer.new()
	barn_rows.add_theme_constant_override("separation", 10)
	barn_panel.add_child(barn_rows)
	ui.add_child(barn_panel)

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
	tool = (SEED_PREFIX + "wheat") if z == "farm" else "buy"
	for k in zone_buttons:
		zone_buttons[k].button_pressed = (k == z)
	for child in tool_bar.get_children():
		tool_bar.remove_child(child)
		child.queue_free()
	tool_buttons.clear()
	var group := ButtonGroup.new()
	var ids: Array[String] = []
	if z == "farm":
		for crop in Catalog.CROPS:
			ids.append(SEED_PREFIX + crop)
	ids.append("buy")
	ids.append_array(Catalog.placeables_for(z))
	ids.append("remove")
	for id in ids:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(124, 72)
		b.button_pressed = (id == tool)
		b.pressed.connect(_select_tool.bind(id))
		tool_bar.add_child(b)
		tool_buttons[id] = b
	camera.position = Iso.cell_to_world(GameState.start_cell())
	camera.zoom = Vector2.ONE * clampf(get_viewport_rect().size.x / START_VIEW_WIDTH, 0.6, 1.4)
	if z == "farm":
		show_message("HINT_FARM")
	else:
		show_message("HINT_START")
	queue_redraw()

func _select_tool(id: String) -> void:
	tool = id
	_refresh_text()

func _tool_label(id: String) -> String:
	if id == "buy":
		return "%s\n%d" % [Loc.t("TOOL_BUY"), GameState.land_cost(zone)]
	if id == "remove":
		return Loc.t("TOOL_REMOVE")
	if id.begins_with(SEED_PREFIX):
		var crop: Dictionary = Catalog.CROPS[id.substr(SEED_PREFIX.length())]
		return "%s\n%d" % [Loc.t("SEED_FMT") % Loc.t(crop.name), crop.seed]
	var def: Dictionary = Catalog.PLACEABLES[id]
	return "%s\n%d" % [Loc.t(def.name), def.cost]

func _refresh_text() -> void:
	coins_label.text = Loc.t("HUD_COINS") % GameState.coins
	barn_button.text = Loc.t("BTN_BARN") % [GameState.inventory.total(), GameState.inventory.capacity]
	zone_buttons["restaurant"].text = Loc.t("ZONE_RESTAURANT")
	zone_buttons["farm"].text = Loc.t("ZONE_FARM")
	lang_button.text = Loc.t("LANG_BUTTON")
	for id in tool_buttons:
		tool_buttons[id].text = _tool_label(id)
	var msg := Loc.t(message_key)
	message_label.text = msg % message_arg if message_arg != null else msg

func _on_state_changed() -> void:
	_refresh_text()
	if barn_panel.visible:
		_refresh_barn()
	queue_redraw()

func _on_language_changed() -> void:
	_refresh_text()
	if barn_panel.visible:
		_refresh_barn()

func _toggle_barn() -> void:
	barn_panel.visible = not barn_panel.visible
	if barn_panel.visible:
		_refresh_barn()

func _refresh_barn() -> void:
	for child in barn_rows.get_children():
		barn_rows.remove_child(child)
		child.queue_free()
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = Loc.t("BARN_TITLE")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = Loc.t("BTN_CLOSE")
	close.custom_minimum_size = Vector2(100, 56)
	close.pressed.connect(_toggle_barn)
	head.add_child(close)
	barn_rows.add_child(head)
	var inv := GameState.inventory
	if inv.items.is_empty():
		var empty := Label.new()
		empty.text = Loc.t("BARN_EMPTY")
		barn_rows.add_child(empty)
		barn_rows.add_child(_test_coins_button())
		return
	var worth := 0
	for item in inv.items:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s  x%d" % [Loc.t(Catalog.ITEMS[item].name), inv.count(item)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var sell := Button.new()
		sell.text = "%s +%d" % [Loc.t("BTN_SELL"), inv.count(item) * int(Catalog.ITEMS[item].sell)]
		sell.custom_minimum_size = Vector2(150, 56)
		sell.pressed.connect(_sell_item.bind(item))
		row.add_child(sell)
		barn_rows.add_child(row)
		worth += inv.count(item) * int(Catalog.ITEMS[item].sell)
	var all := Button.new()
	all.text = Loc.t("BTN_SELL_ALL") % worth
	all.custom_minimum_size = Vector2(0, 64)
	all.pressed.connect(_sell_everything)
	barn_rows.add_child(all)
	barn_rows.add_child(_test_coins_button())

func _test_coins_button() -> Button:
	var b := Button.new()
	b.text = Loc.t("BTN_TEST_COINS") % GameState.TEST_GRANT
	b.custom_minimum_size = Vector2(0, 56)
	b.modulate = Color(1, 1, 1, 0.75)
	b.pressed.connect(GameState.grant_test_coins)
	return b

func _sell_item(item: String) -> void:
	var earned := GameState.sell(item, GameState.inventory.count(item))
	if earned > 0:
		show_message("MSG_SOLD", earned)

func _sell_everything() -> void:
	var earned := GameState.sell_all()
	if earned > 0:
		show_message("MSG_SOLD", earned)

func show_message(key: String, arg = null) -> void:
	message_key = key
	message_arg = arg
	message_time = 4.0
	_refresh_text()

func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		message_label.modulate.a = clampf(message_time, 0.0, 1.0)
	if zone == "farm":
		redraw_timer += delta
		if redraw_timer >= REDRAW_EVERY:
			redraw_timer = 0.0
			queue_redraw()

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
	queue_redraw()

func _clamp_camera() -> void:
	var s := GameState.GRID_SIZE
	var lo := Vector2(Iso.cell_to_world(Vector2i(0, s.y)).x, 0.0)
	var hi := Vector2(Iso.cell_to_world(Vector2i(s.x, 0)).x, Iso.cell_to_world(s).y)
	camera.position = camera.position.clamp(lo, hi)
	queue_redraw()

func _fmt_time(seconds: int) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), seconds % 60]

func _on_tap(world: Vector2) -> void:
	var c := Iso.world_to_cell(world)
	var g := GameState.grid(zone)
	if not g.in_bounds(c):
		return
	if tool.begins_with(SEED_PREFIX):
		_report_farm(GameState.interact(zone, c, tool.substr(SEED_PREFIX.length())), c)
		return
	var result := ""
	var amount := 0
	if tool == "buy":
		amount = GameState.land_cost(zone)
		result = GameState.buy_land(zone, c)
	elif tool == "remove":
		amount = GameState.refund_for(zone, c)
		result = GameState.remove_object(zone, c)
	else:
		result = GameState.place_object(zone, c, tool)
	match result:
		"ok":
			if tool == "buy":
				show_message("MSG_BOUGHT", amount)
			elif tool == "remove":
				show_message("MSG_REMOVED", amount)
			else:
				show_message("MSG_PLACED")
		"no_coins": show_message("MSG_NO_COINS")
		"locked": show_message("MSG_LOCKED")
		"occupied": show_message("MSG_OCCUPIED")
		"empty": show_message("MSG_EMPTY")
		_: show_message("MSG_INVALID")

func _report_farm(result: String, c: Vector2i) -> void:
	match result:
		"planted": show_message("MSG_PLANTED")
		"harvested": show_message("MSG_HARVESTED")
		"fed": show_message("MSG_FED")
		"collected": show_message("MSG_COLLECTED")
		"growing": show_message("MSG_GROWING", _fmt_time(GameState.seconds_left(zone, c)))
		"busy": show_message("MSG_BUSY", _fmt_time(GameState.seconds_left(zone, c)))
		"no_coins": show_message("MSG_NO_COINS")
		"no_feed": show_message("MSG_NO_FEED")
		"full": show_message("MSG_FULL")
		_: show_message("MSG_INVALID")

func _visible_cell_range(g: WorldGrid) -> Rect2i:
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
	var vis := _visible_cell_range(g)
	for y in range(vis.position.y, vis.end.y):
		for x in range(vis.position.x, vis.end.x):
			var c := Vector2i(x, y)
			var p := Iso.cell_to_world(c)
			if g.is_owned(c):
				_draw_floor(Catalog.FLOOR[zone], p, Catalog.FLOOR_COLOR[zone])
			else:
				_draw_floor(Catalog.LOCKED_TILE, p, Color("2f3a33"), Color(0.6, 0.65, 0.7))
	_draw_buyable_parcels(g)
	var origins: Array = g.objects.keys()
	origins.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x + a.y + g.footprints[a].x + g.footprints[a].y < b.x + b.y + g.footprints[b].x + g.footprints[b].y)
	for o in origins:
		_draw_object(o, g.objects[o])

func _draw_buyable_parcels(g: WorldGrid) -> void:
	var font := ThemeDB.fallback_font
	var psize := Vector2i.ONE * WorldGrid.PARCEL
	for py in range(g.parcel_grid().y):
		for px in range(g.parcel_grid().x):
			var parcel := Vector2i(px, py)
			if not g.can_buy_parcel(parcel):
				continue
			var origin := parcel * WorldGrid.PARCEL
			var pts := Iso.footprint_corners(origin, psize)
			draw_colored_polygon(pts, Color(1.0, 0.84, 0.42, 0.10))
			pts.append(pts[0])
			draw_polyline(pts, Color("ffd66b"), 4.0)
			var label := str(GameState.land_cost(zone))
			var at := Iso.footprint_center(origin, psize) + Vector2(-60, 12)
			draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 120, 40, 8, Color("1b1208"))
			draw_string(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 120, 40, Color("ffd66b"))

func _diamond(p: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(0, -hh), p + Vector2(hw, 0), p + Vector2(0, hh), p + Vector2(-hw, 0)])

# Floor-style art: the canvas width maps to `width`, the diamond is centred in the canvas.
func _draw_flat_art(id: String, center: Vector2, width: float, tint: Color = Color.WHITE) -> bool:
	var tex := Assets.get_tex(id)
	if tex == null:
		return false
	var s := tex.get_size() * (width / tex.get_width())
	draw_texture_rect(tex, Rect2(center - s * 0.5, s), false, tint)
	return true

func _draw_floor(id: String, p: Vector2, fallback: Color, tint: Color = Color.WHITE) -> void:
	if _draw_flat_art(id, p, Iso.TILE_W, tint):
		return
	var pts := _diamond(p, Iso.TILE_W * 0.5, Iso.TILE_H * 0.5)
	draw_colored_polygon(pts, fallback)
	pts.append(pts[0])
	draw_polyline(pts, fallback.darkened(0.25), 1.0)

# Upright art: the canvas width maps to the footprint width and its bottom edge sits on the footprint's bottom corner.
func _draw_sprite(id: String, origin: Vector2i, sz: Vector2i) -> bool:
	var tex := Assets.get_tex(id)
	if tex == null:
		return false
	var s := tex.get_size() * (Iso.footprint_width(sz) / tex.get_width())
	var foot := Iso.footprint_center(origin, sz) + Vector2(0, Iso.footprint_height(sz) * 0.5)
	draw_texture_rect(tex, Rect2(foot - Vector2(s.x * 0.5, s.y), s), false)
	return true

func _object_height(sz: Vector2i) -> float:
	return 9.5 * (sz.x + sz.y)

func _draw_object(origin: Vector2i, id: String) -> void:
	var def: Dictionary = Catalog.PLACEABLES[id]
	var sz: Vector2i = def.size
	if def.get("flat", false):
		_draw_plot(origin, sz)
		return
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
