extends Node2D

const TAP_SLOP := 12.0
const ZOOM_MIN := 0.22
const ZOOM_MAX := 2.2
const START_VIEW_WIDTH := 1000.0
const NONE := WorldGrid.NONE

var zone: String = "restaurant"
var camera: Camera2D
var hud: Hud
var view := ViewState.new()
var renderer: WorldRenderer
var decor: SceneDecor
var editor: MapEditor
var editor_ui: EditorUI
var painting := false

# Placement mode: choosing a spot for a new item (placing_id) or for an existing one (moving_origin).
var placing_id: String = ""
var moving_origin: Vector2i = NONE
var placing_from_stash: bool = false   # placing a piece out of the storage: free
var moving_top: bool = false         # the thing being moved is one standing on a table
var placing_facing: int = 0          # turn of the item being placed or moved (0 front, 1 left, 2 back, 3 right)
var ghost_cell: Vector2i = Vector2i.ZERO   # in units (Iso.SUB per cell)
var selected_origin: Vector2i = NONE
var selected_top: bool = false       # the selected thing stands on a table (WorldGrid.tops), not on the floor
var selected_obstacle: Vector2i = NONE
var selected_land: Vector2i = NONE   # a cell on an owned, empty block of the restaurant (opens the floor/grass bubble)
var context_timer: float = 0.0
var view_timer: float = 0.0

var pressing := false
var dragged := false
var press_pos := Vector2.ZERO
var touches: Dictionary = {}
var pinch_dist := 0.0
var pinched := false

func _ready() -> void:
	camera = Camera2D.new()
	add_child(camera)
	renderer = WorldRenderer.new()
	add_child(renderer)
	renderer.setup(view, camera)
	decor = SceneDecor.new()
	decor.setup(view)
	add_child(decor)
	hud = Hud.new()
	add_child(hud)
	hud.edit_map_requested.connect(func() -> void:
		hud.close_modal()
		hud.ask_confirm(Loc.t("CONFIRM_EDIT_MAP"), open_editor))
	hud.zone_toggled.connect(func() -> void: set_zone("farm" if zone == "restaurant" else "restaurant"))
	hud.item_picked.connect(start_placement)
	hud.crop_chosen.connect(_on_crop_chosen)
	hud.action_pressed.connect(_on_action_pressed)
	hud.move_requested.connect(_on_move_requested)
	hud.rotate_requested.connect(_on_rotate_requested)
	hud.placement_rotated.connect(rotate_ghost)
	hud.store_requested.connect(_on_store_requested)
	hud.stash_item_picked.connect(start_placement.bind(true))
	hud.placement_confirmed.connect(confirm_placement)
	hud.placement_cancelled.connect(cancel_placement)
	hud.reset_confirmed.connect(_on_reset)
	GameState.changed.connect(_on_state_changed)
	GameState.leveled_up.connect(_on_leveled_up)
	GameState.restaurant.customer_left.connect(func(_id: int) -> void: hud.show_message("MSG_CUSTOMER_LEFT"))
	Loc.changed.connect(_on_state_changed)
	set_zone("restaurant")

# ---------------------------------------------------------------- backdrop

func _sync_view() -> void:
	view.zone = zone
	view.ghost_id = placing_id
	view.ghost_cell = ghost_cell
	view.ghost_facing = placing_facing
	view.ghost_status = placement_status()
	view.moving_origin = moving_origin
	view.selected_origin = selected_origin
	view.selected_top = selected_top
	view.selected_obstacle = selected_obstacle
	view.selected_land = selected_land
	view.edit_mode = editor != null
	view.edit_tool = editor.tool if editor != null else ""
	view.customers = GameState.restaurant.snapshot_customers()
	view.counter = GameState.restaurant.counter.duplicate()

# Tells the renderer something visible changed.
func _redraw_all() -> void:
	if renderer == null:
		return
	_sync_view()
	renderer.refresh()
	decor.queue_redraw()

# ---------------------------------------------------------------- map editor

func open_editor() -> void:
	if editor != null:
		return
	cancel_placement()
	_deselect()
	editor = MapEditor.new()
	editor.begin(zone)
	editor.changed.connect(_on_editor_changed)
	editor_ui = EditorUI.new()
	editor_ui.setup(editor)
	editor_ui.leave_requested.connect(close_editor)
	editor_ui.scene_changed.connect(func(z: String) -> void: set_zone(z))
	add_child(editor_ui)
	hud.visible = false
	_on_editor_changed()

func close_editor(keep: bool) -> void:
	if editor == null:
		return
	painting = false
	editor.finish(keep)
	editor_ui.queue_free()
	editor_ui = null
	editor = null
	hud.visible = true
	set_zone(zone)
	hud.refresh()

# The map changed: terrain colours, shoreline, decor and objects are all drawn from it.
func _on_editor_changed() -> void:
	renderer.set_zone(zone)
	decor.set_zone(zone)
	_redraw_all()

# ---------------------------------------------------------------- zones & state

func set_zone(z: String) -> void:
	zone = z
	cancel_placement()
	_deselect()
	hud.close_modal()
	hud.set_zone(z)
	_sync_view()
	renderer.set_zone(z)
	decor.set_zone(z)
	camera.position = Iso.cell_to_world(GameState.layout_for(z).start_cell())
	camera.zoom = Vector2.ONE * clampf(get_viewport_rect().size.x / START_VIEW_WIDTH, 0.6, 1.4)
	hud.show_message("HINT_FARM" if z == "farm" else "HINT_START")
	_redraw_all()

func _on_state_changed() -> void:
	hud.refresh()
	if selected_origin != NONE:
		if _selected_exists():
			hud.show_context(_context_info(selected_origin))
		else:
			_deselect()
	if selected_land != NONE:
		hud.show_context(_land_info(selected_land))
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
		"area": return ["MSG_WRONG_AREA", null]
		"no_surface": return ["MSG_NEED_TABLE", null]
		"level": return ["MSG_LEVEL", Catalog.unlock_level(item_id) if item_id != "" else null]
	return ["MSG_INVALID", null]

# ---------------------------------------------------------------- placement mode

func start_placement(id: String, from_stash: bool = false) -> void:
	_deselect()
	placing_id = id
	placing_from_stash = from_stash
	moving_origin = NONE
	moving_top = false
	placing_facing = 0
	ghost_cell = Iso.world_to_unit(camera.position)
	_update_placement_ui()
	_redraw_all()

func start_move(origin: Vector2i, top: bool = false) -> void:
	var g := GameState.grid(zone)
	if not (g.tops if top else g.objects).has(origin):
		return
	_deselect()
	placing_from_stash = false
	placing_id = g.tops[origin] if top else g.objects[origin]
	moving_origin = origin
	moving_top = top
	placing_facing = 0 if top else g.facing_at(origin)
	var sz: Vector2i = g.top_footprints[origin] if top else g.footprints[origin]
	ghost_cell = origin + Vector2i(floori((sz.x - 1) / 2.0), floori((sz.y - 1) / 2.0))
	_update_placement_ui()
	_redraw_all()

func set_ghost(c: Vector2i) -> void:
	ghost_cell = c
	_update_placement_ui()
	_redraw_all()

# Turns the item being placed a quarter turn (the bar's turn button).
func rotate_ghost() -> void:
	if placing_id == "" or moving_origin != NONE or not Catalog.is_rotatable(placing_id):
		return
	placing_facing = (placing_facing + 1) % 4
	_update_placement_ui()
	_redraw_all()

func placement_status() -> String:
	if placing_id == "":
		return ""
	if moving_origin != NONE:
		return GameState.check_move(zone, moving_origin, ghost_cell, moving_top)
	return GameState.check_place(zone, ghost_cell, placing_id, placing_facing, placing_from_stash)

func _update_placement_ui() -> void:
	var st := placement_status()
	var def: Dictionary = Catalog.PLACEABLES[placing_id]
	var detail := Loc.t("PLACE_HINT")
	if st == "ok":
		if moving_origin == NONE:
			detail = Loc.t("FROM_STORAGE") % GameState.stash_count(placing_id) if placing_from_stash else str(GameState.place_cost(placing_id))
	else:
		var e := _error_text(st, placing_id)
		detail = Loc.t(e[0]) % e[1] if e[1] != null else Loc.t(e[0])
	hud.show_placement("%s\n%s" % [Loc.t(def.name), detail], st == "ok", moving_origin != NONE, Catalog.is_rotatable(placing_id) and moving_origin == NONE)

func confirm_placement() -> void:
	if placing_id == "":
		return
	var st := placement_status()
	if st != "ok":
		var e := _error_text(st, placing_id)
		hud.show_message(e[0], e[1])
		return
	if moving_origin != NONE:
		GameState.move_object(zone, moving_origin, ghost_cell, moving_top)
		cancel_placement()
		hud.show_message("MSG_MOVED")
		return
	var cost := GameState.place_cost(placing_id)
	var at := Iso.unit_to_world(ghost_cell)
	GameState.place_object(zone, ghost_cell, placing_id, placing_facing, placing_from_stash)
	if not placing_from_stash:
		hud.float_text("-%d" % cost, _screen_of(at), UiTheme.BAD)
	hud.show_message("MSG_PLACED")
	if placing_from_stash and GameState.stash_count(placing_id) <= 0:
		cancel_placement()   # the last one out of the storage
		return
	# Step the ghost along so rows of plots or fences go down quickly.
	set_ghost(ghost_cell + Vector2i(Catalog.size_facing(placing_id, placing_facing).x, 0))

func cancel_placement() -> void:
	placing_id = ""
	moving_origin = NONE
	moving_top = false
	placing_from_stash = false
	placing_facing = 0
	if hud != null:
		hud.hide_placement()
	_redraw_all()

# ---------------------------------------------------------------- selecting & interacting

func _deselect() -> void:
	selected_origin = NONE
	selected_top = false
	selected_obstacle = NONE
	selected_land = NONE
	if hud != null:
		hud.hide_context()
	_redraw_all()

func _on_tap(world: Vector2) -> void:
	var c := Iso.world_to_cell(world)
	var u := Iso.world_to_unit(world)   # things stand on the finer unit grid, land on whole cells
	var g := GameState.grid(zone)
	if placing_id != "":
		if g.in_bounds(c):
			set_ghost(u)
		return
	if not g.in_bounds(c):
		_deselect()
		return
	var on_table := g.top_origin_at(u)   # a vase on a table is tapped before the table under it
	if on_table != NONE:
		_select(on_table, true)
		return
	var origin := g.origin_at(u)
	if origin != NONE:
		_select(origin)
		return
	if g.blocked.has(c) and g.is_owned(c):
		_select_obstacle(c)
		return
	_deselect()
	var parcel := WorldGrid.parcel_of(c)
	if g.is_owned(c):
		if zone == "restaurant":
			_select_land(c)
		return
	if g.can_buy_parcel(parcel):
		_ask_buy(c)
	elif GameState.layout_for(zone).in_bounds(c) and GameState.layout_for(zone).tile_at(c) != SceneLayout.Tile.WATER:
		hud.show_message("MSG_AREA_FAR" if GameState.layout_for(zone).for_sale(parcel) else "MSG_AREA_INFO")

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

func _select(origin: Vector2i, top: bool = false) -> void:
	selected_origin = origin
	selected_top = top
	if top:
		hud.show_context(_context_info(origin))
		_redraw_all()
		return
	var id: String = GameState.grid(zone).objects[origin]
	if (id == "farm_plot_01" or id == "farm_coop_01") and GameState.progress(zone, origin) >= 1.0:
		_do_interact(origin, "")
		_deselect()
		return
	hud.show_context(_context_info(origin))
	_redraw_all()

func _select_land(c: Vector2i) -> void:
	selected_land = c
	hud.show_context(_land_info(c))
	_redraw_all()

func _land_info(c: Vector2i) -> Dictionary:
	var g := GameState.grid(zone)
	var parcel := WorldGrid.parcel_of(c)
	var info := {"title": Loc.t("AREA_SHOP" if GameState.layout_for(zone).is_start_parcel(parcel) else "AREA_PLOT"), "plain": true}
	if GameState.layout_for(zone).is_start_parcel(parcel):
		info.status = Loc.t("STATUS_FLOOR_FIXED")
	elif g.has_floor(parcel):
		info.status = Loc.t("STATUS_FLOOR")
		info.action = {"text": Loc.t("BTN_GRASS"), "enabled": true}
	else:
		info.status = Loc.t("STATUS_GRASS")
		info.action = {"text": Loc.t("BTN_FLOOR") % GameState.FLOOR_COST, "enabled": GameState.coins >= GameState.FLOOR_COST}
	return info

func _toggle_land_floor() -> void:
	var c := selected_land
	var want := not GameState.grid(zone).has_floor(WorldGrid.parcel_of(c))
	match GameState.set_floor(zone, c, want):
		"ok": hud.show_message("MSG_FLOOR_BUILT" if want else "MSG_FLOOR_REMOVED")
		"no_coins": hud.show_message("MSG_NO_COINS")
		_: hud.show_message("MSG_INVALID")
	_deselect()

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
	if selected_top:
		var tid: String = g.tops[origin]
		return {"title": Loc.t(Catalog.PLACEABLES[tid].name), "status": "", "can_rotate": false}
	var id: String = g.objects[origin]
	var def: Dictionary = Catalog.PLACEABLES[id]
	var info := {"title": Loc.t(def.name), "status": "", "can_rotate": Catalog.is_rotatable(id)}
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
	elif id == "rest_stove_01":
		if prog < 0.0:
			info.status = Loc.t("STATUS_STOVE_IDLE")
		else:
			var dish: String = g.states[origin].dish
			info.status = Loc.t("STATUS_STOVE_BUSY") % [Loc.t(Catalog.RECIPES[dish].name), _fmt_time(GameState.seconds_left(zone, origin))]
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
	if selected_land != NONE:
		_toggle_land_floor()
		return
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
	var at := _screen_of(Iso.unit_center(origin, g.footprints[origin]))
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
		start_move(selected_origin, selected_top)

# Turns the selected object a quarter turn.
func _on_rotate_requested() -> void:
	if selected_origin == NONE:
		return
	var next_origin := GameState.origin_after_rotate(zone, selected_origin) if GameState.grid(zone).objects.has(selected_origin) else selected_origin
	var st := GameState.rotate_object(zone, selected_origin)
	if st != "ok":
		var e := _error_text(st)
		hud.show_message(e[0], e[1])
		return
	selected_origin = next_origin   # a turn about the middle moves the top-left corner
	hud.show_context(_context_info(selected_origin))
	_redraw_all()

# Takes the selected thing off the floor into the storage (selling is done from the storage, by choice).
func _on_store_requested() -> void:
	if selected_origin == NONE:
		return
	var origin := selected_origin
	var top := selected_top
	if GameState.store_loses_state(zone, origin, top):
		hud.ask_confirm(Loc.t("CONFIRM_STORE_STATE"), _store.bind(origin, top))
		return
	_store(origin, top)

func _store(origin: Vector2i, top: bool) -> void:
	if GameState.store_object(zone, origin, top) == "ok":
		hud.show_message("MSG_STORED")
	_deselect()

# ---------------------------------------------------------------- frame & input

func _process(delta: float) -> void:
	view_timer += delta
	if view_timer >= 0.5:
		view_timer = 0.0
		_sync_view()
	if selected_land != NONE and hud.context.visible:
		hud.place_context(_screen_of(Iso.cell_to_world(selected_land) + Vector2(0, -30)))
	if selected_obstacle != NONE and hud.context.visible:
		hud.place_context(_screen_of(Iso.cell_to_world(selected_obstacle) + Vector2(0, -50)))
	if selected_origin != NONE and hud.context.visible:
		var g := GameState.grid(zone)
		if _selected_exists():
			var sc := Iso.unit_corners(selected_origin, (g.top_footprints if selected_top else g.footprints)[selected_origin])
			hud.place_context(_screen_of((sc[0] + sc[1]) * 0.5 + Vector2(0, -24)))
		context_timer += delta
		if context_timer >= 1.0:
			context_timer = 0.0
			if _selected_exists():
				hud.show_context(_context_info(selected_origin))

# Whether the selected thing is still there (it may have been sold or carried off).
func _selected_exists() -> bool:
	var g := GameState.grid(zone)
	return (g.tops if selected_top else g.objects).has(selected_origin)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
			pinch_dist = 0.0
		if touches.size() >= 2:
			pinched = true
			if painting:
				painting = false
				editor.end_stroke()
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
				if editor != null and editor.tool != "hand" and not pinched and touches.size() < 2:
					painting = true
					editor.begin_stroke()
					editor.apply_at(get_global_mouse_position())
			else:
				if painting:
					painting = false
					editor.end_stroke()
				elif pressing and not dragged and not pinched and editor == null:
					_on_tap(get_global_mouse_position())
				pressing = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / 1.1)
	elif event is InputEventMouseMotion and pressing and not pinched:
		if painting:
			editor.apply_at(get_global_mouse_position())
		else:
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
	var s := GameState.grid(zone).size
	var lo := Iso.cell_to_world(Vector2i.ZERO)
	var hi := Iso.cell_to_world(s)
	camera.position = camera.position.clamp(lo, hi)
	_redraw_all()
