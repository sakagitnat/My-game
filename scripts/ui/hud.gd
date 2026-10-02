class_name Hud
extends CanvasLayer

signal zone_toggled
signal item_picked(id: String)
signal crop_chosen(crop: String)
signal move_requested
signal sell_requested
signal action_pressed
signal placement_confirmed
signal placement_cancelled
signal reset_confirmed

const MODAL_MAX_WIDTH := 640.0

var zone: String = "restaurant"
var root: Control
var level_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var coins_label: Label
var menu_button: Button
var zone_button: Button
var shop_button: Button
var barn_button: Button
var message_label: Label
var message_key := "HINT_START"
var message_arg = null
var message_time := 0.0
var placement_bar: PanelContainer
var placement_title: Label
var placement_ok: Button
var modal: Control
var modal_panel: PanelContainer
var modal_body: VBoxContainer
var modal_kind := ""
var confirm_text := ""
var confirm_yes := Callable()
var context: PanelContainer
var context_body: VBoxContainer

func _ready() -> void:
	layer = 10
	_build()
	refresh()

func _viewport_size() -> Vector2:
	return root.get_viewport_rect().size if root != null and root.is_inside_tree() else Vector2(1280, 720)

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.build()
	add_child(root)

	var status := PanelContainer.new()
	status.position = Vector2(12, 12)
	root.add_child(status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	status.add_child(row)
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 30)
	level_label.add_theme_color_override("font_color", UiTheme.GOLD)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(level_label)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 8)
	col.add_child(coin_row)
	var coin := Panel.new()
	coin.custom_minimum_size = Vector2(24, 24)
	coin.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.GOLD, Color("a8761f"), 12, 0, 3))
	coin_row.add_child(coin)
	coins_label = Label.new()
	coin_row.add_child(coins_label)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(190, 22)
	xp_bar.show_percentage = false
	col.add_child(xp_bar)
	xp_label = Label.new()
	xp_label.add_theme_font_size_override("font_size", 16)
	xp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_bar.add_child(xp_label)

	menu_button = _corner_button(Control.PRESET_TOP_RIGHT, Vector2(120, 60))
	menu_button.pressed.connect(open_modal.bind("settings"))

	zone_button = _corner_button(Control.PRESET_BOTTOM_LEFT, Vector2(220, 72))
	zone_button.pressed.connect(func() -> void: zone_toggled.emit())

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 1.0
	right.anchor_bottom = 1.0
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -12
	right.offset_bottom = -12
	root.add_child(right)
	shop_button = Button.new()
	shop_button.custom_minimum_size = Vector2(150, 72)
	shop_button.pressed.connect(open_modal.bind("shop"))
	right.add_child(shop_button)
	barn_button = Button.new()
	barn_button.custom_minimum_size = Vector2(170, 72)
	barn_button.pressed.connect(open_modal.bind("barn"))
	right.add_child(barn_button)

	message_label = Label.new()
	message_label.anchor_left = 0.0
	message_label.anchor_right = 1.0
	message_label.anchor_top = 1.0
	message_label.anchor_bottom = 1.0
	message_label.offset_top = -150
	message_label.offset_bottom = -104
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 8)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(message_label)

	placement_bar = PanelContainer.new()
	placement_bar.visible = false
	placement_bar.anchor_left = 0.5
	placement_bar.anchor_right = 0.5
	placement_bar.anchor_top = 1.0
	placement_bar.anchor_bottom = 1.0
	placement_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	placement_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	placement_bar.offset_bottom = -100
	root.add_child(placement_bar)
	var pb := HBoxContainer.new()
	pb.add_theme_constant_override("separation", 14)
	placement_bar.add_child(pb)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.custom_minimum_size = Vector2(120, 64)
	cancel.pressed.connect(func() -> void: placement_cancelled.emit())
	pb.add_child(cancel)
	placement_title = Label.new()
	placement_title.custom_minimum_size = Vector2(190, 0)
	placement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placement_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placement_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pb.add_child(placement_title)
	placement_ok = Button.new()
	placement_ok.custom_minimum_size = Vector2(120, 64)
	placement_ok.pressed.connect(func() -> void: placement_confirmed.emit())
	pb.add_child(placement_ok)

	context = PanelContainer.new()
	context.visible = false
	root.add_child(context)
	context_body = VBoxContainer.new()
	context_body.add_theme_constant_override("separation", 8)
	context.add_child(context_body)

	modal = Control.new()
	modal.visible = false
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)
	modal_panel = PanelContainer.new()
	center.add_child(modal_panel)
	modal_body = VBoxContainer.new()
	modal_body.add_theme_constant_override("separation", 10)
	modal_panel.add_child(modal_body)

func _corner_button(preset: int, size: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.set_anchors_preset(preset)
	b.grow_horizontal = Control.GROW_DIRECTION_BEGIN if preset == Control.PRESET_TOP_RIGHT else Control.GROW_DIRECTION_END
	b.grow_vertical = Control.GROW_DIRECTION_END if preset == Control.PRESET_TOP_RIGHT else Control.GROW_DIRECTION_BEGIN
	b.offset_left = -size.x - 12 if preset == Control.PRESET_TOP_RIGHT else 12
	b.offset_right = -12 if preset == Control.PRESET_TOP_RIGHT else size.x + 12
	b.offset_top = 12 if preset == Control.PRESET_TOP_RIGHT else -size.y - 12
	b.offset_bottom = size.y + 12 if preset == Control.PRESET_TOP_RIGHT else -12
	root.add_child(b)
	return b

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_modal()

# ---------------------------------------------------------------- status

func set_zone(z: String) -> void:
	zone = z
	refresh()

func refresh() -> void:
	if root == null:
		return
	level_label.text = Loc.t("LEVEL_FMT") % GameState.level
	coins_label.text = str(GameState.coins)
	xp_bar.max_value = GameState.xp_for_next()
	xp_bar.value = GameState.xp
	xp_label.text = "%d / %d" % [GameState.xp, GameState.xp_for_next()]
	menu_button.text = Loc.t("BTN_MENU")
	shop_button.text = Loc.t("BTN_SHOP")
	barn_button.text = Loc.t("BTN_BARN") % [GameState.inventory.total(), GameState.inventory.capacity]
	zone_button.text = Loc.t("GO_FARM") if zone == "restaurant" else Loc.t("GO_RESTAURANT")
	placement_ok.text = Loc.t("BTN_PLACE")
	var msg := Loc.t(message_key)
	message_label.text = msg % message_arg if message_arg != null else msg
	if modal.visible:
		_build_modal()

func show_message(key: String, arg = null) -> void:
	message_key = key
	message_arg = arg
	message_time = 4.0
	message_label.modulate.a = 1.0
	refresh()

func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		message_label.modulate.a = clampf(message_time, 0.0, 1.0)

func float_text(text: String, screen_pos: Vector2, color: Color = Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = screen_pos - Vector2(40, 20)
	root.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 70.0, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)

# ---------------------------------------------------------------- placement bar

func show_placement(title: String, valid: bool, moving: bool = false) -> void:
	placement_bar.visible = true
	var cancel: Button = placement_bar.find_child("Cancel", true, false)
	cancel.text = Loc.t("BTN_CANCEL" if moving else "BTN_DONE")
	message_label.visible = false
	placement_title.text = title
	placement_ok.disabled = not valid
	placement_title.add_theme_color_override("font_color", UiTheme.TEXT if valid else UiTheme.BAD)

func hide_placement() -> void:
	placement_bar.visible = false
	message_label.visible = true

# ---------------------------------------------------------------- context bubble

func hide_context() -> void:
	context.visible = false

# info: {title, status, crops: [{id, text, enabled}], sell: int, can_move: bool}
func show_context(info: Dictionary) -> void:
	for child in context_body.get_children():
		context_body.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = info.get("title", "")
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	context_body.add_child(title)
	if info.get("status", "") != "":
		var st := Label.new()
		st.text = info.status
		st.add_theme_font_size_override("font_size", 18)
		context_body.add_child(st)
	if info.has("action"):
		var ab := Button.new()
		ab.text = info.action.text
		ab.disabled = not info.action.enabled
		ab.custom_minimum_size = Vector2(0, 60)
		ab.pressed.connect(func() -> void: action_pressed.emit())
		context_body.add_child(ab)
	var crops: Array = info.get("crops", [])
	if not crops.is_empty():
		var cl := Label.new()
		cl.text = Loc.t("CHOOSE_CROP")
		cl.add_theme_font_size_override("font_size", 18)
		context_body.add_child(cl)
		var cr := HBoxContainer.new()
		cr.add_theme_constant_override("separation", 8)
		context_body.add_child(cr)
		for c in crops:
			var b := Button.new()
			b.text = c.text
			b.disabled = not c.enabled
			b.custom_minimum_size = Vector2(112, 68)
			b.pressed.connect(func() -> void: crop_chosen.emit(c.id))
			cr.add_child(b)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	context_body.add_child(actions)
	var mv := Button.new()
	mv.text = Loc.t("BTN_MOVE")
	mv.custom_minimum_size = Vector2(110, 56)
	mv.pressed.connect(func() -> void: move_requested.emit())
	actions.add_child(mv)
	var sell := Button.new()
	sell.text = Loc.t("BTN_SELL_OBJ") % int(info.get("sell", 0))
	sell.custom_minimum_size = Vector2(150, 56)
	sell.pressed.connect(func() -> void: sell_requested.emit())
	actions.add_child(sell)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(56, 56)
	close.pressed.connect(hide_context)
	actions.add_child(close)
	context.visible = true
	context.reset_size()

# Keeps the bubble just above `screen_pos`, inside the visible area.
func place_context(screen_pos: Vector2) -> void:
	if not context.visible:
		return
	var vp := _viewport_size()
	var sz := context.size
	var p := screen_pos - Vector2(sz.x * 0.5, sz.y + 24.0)
	p.x = clampf(p.x, 8.0, maxf(8.0, vp.x - sz.x - 8.0))
	p.y = clampf(p.y, 84.0, maxf(84.0, vp.y - sz.y - 100.0))
	context.position = p

# ---------------------------------------------------------------- modal panels

func open_modal(kind: String) -> void:
	hide_context()
	modal_kind = kind
	modal.visible = true
	_build_modal()

func close_modal() -> void:
	modal.visible = false
	modal_kind = ""

func ask_confirm(text: String, on_yes: Callable) -> void:
	hide_context()
	confirm_text = text
	confirm_yes = on_yes
	modal_kind = "confirm"
	modal.visible = true
	_build_modal()

func _clear_modal() -> void:
	for child in modal_body.get_children():
		modal_body.remove_child(child)
		child.queue_free()

func _modal_header(title: String) -> void:
	var head := HBoxContainer.new()
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", UiTheme.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = Loc.t("BTN_CLOSE")
	close.custom_minimum_size = Vector2(110, 56)
	close.pressed.connect(close_modal)
	head.add_child(close)
	modal_body.add_child(head)

func _scroll_area(rows: int = 6) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, minf(_viewport_size().y * 0.5, maxf(rows, 1) * 72.0))
	modal_body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list

func _build_modal() -> void:
	_clear_modal()
	modal_panel.custom_minimum_size = Vector2(clampf(_viewport_size().x - 40.0, 300.0, MODAL_MAX_WIDTH), 0)
	match modal_kind:
		"shop": _build_shop()
		"barn": _build_barn()
		"settings": _build_settings()
		"confirm": _build_confirm()

func _build_shop() -> void:
	_modal_header(Loc.t("SHOP_TITLE") + " - " + Loc.t("ZONE_RESTAURANT" if zone == "restaurant" else "ZONE_FARM"))
	var items := Catalog.placeables_for(zone)
	var list := _scroll_area(items.size())
	for id in items:
		var def: Dictionary = Catalog.PLACEABLES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_l := Label.new()
		name_l.text = Loc.t(def.name)
		info.add_child(name_l)
		var sz_l := Label.new()
		sz_l.text = "%dx%d   %d" % [def.size.x, def.size.y, def.cost]
		sz_l.add_theme_font_size_override("font_size", 16)
		sz_l.add_theme_color_override("font_color", UiTheme.MUTED)
		info.add_child(sz_l)
		row.add_child(info)
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 60)
		var need := Catalog.unlock_level(id)
		if GameState.level < need:
			b.text = Loc.t("LOCKED_LV") % need
			b.disabled = true
		else:
			b.text = Loc.t("BTN_PLACE")
			b.disabled = GameState.coins < int(def.cost)
			b.pressed.connect(func() -> void:
				close_modal()
				item_picked.emit(id))
		row.add_child(b)
		list.add_child(row)

func _build_barn() -> void:
	_modal_header(Loc.t("BARN_TITLE"))
	var inv := GameState.inventory
	var cap := Label.new()
	cap.text = "%d / %d" % [inv.total(), inv.capacity]
	cap.add_theme_color_override("font_color", UiTheme.MUTED)
	modal_body.add_child(cap)
	var list := _scroll_area(inv.items.size())
	var worth := 0
	if inv.items.is_empty():
		var empty := Label.new()
		empty.text = Loc.t("BARN_EMPTY")
		list.add_child(empty)
	for item in inv.items:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s  x%d" % [Loc.t(Catalog.ITEMS[item].name), inv.count(item)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var each: int = inv.count(item) * int(Catalog.ITEMS[item].sell)
		worth += each
		var sell := Button.new()
		sell.text = "%s +%d" % [Loc.t("BTN_SELL"), each]
		sell.custom_minimum_size = Vector2(150, 56)
		sell.pressed.connect(func() -> void:
			var earned := GameState.sell(item, GameState.inventory.count(item))
			if earned > 0:
				show_message("MSG_SOLD", earned))
		row.add_child(sell)
		list.add_child(row)
	if worth > 0:
		var all := Button.new()
		all.text = Loc.t("BTN_SELL_ALL") % worth
		all.custom_minimum_size = Vector2(0, 60)
		all.pressed.connect(func() -> void:
			var earned := GameState.sell_all()
			if earned > 0:
				show_message("MSG_SOLD", earned))
		modal_body.add_child(all)
	var up := Button.new()
	up.text = Loc.t("BTN_UPGRADE_BARN") % [GameState.BARN_STEP, GameState.barn_upgrade_cost()]
	up.custom_minimum_size = Vector2(0, 60)
	up.disabled = GameState.coins < GameState.barn_upgrade_cost()
	up.pressed.connect(func() -> void:
		if GameState.upgrade_barn() == "ok":
			show_message("MSG_BARN_UP"))
	modal_body.add_child(up)

func _build_settings() -> void:
	_modal_header(Loc.t("BTN_MENU"))
	var lang := Button.new()
	lang.text = Loc.t("LANG_BUTTON")
	lang.custom_minimum_size = Vector2(0, 60)
	lang.pressed.connect(Loc.toggle)
	modal_body.add_child(lang)
	var test := Button.new()
	test.text = Loc.t("BTN_TEST_COINS") % GameState.TEST_GRANT
	test.custom_minimum_size = Vector2(0, 60)
	test.pressed.connect(GameState.grant_test_coins)
	modal_body.add_child(test)
	var reset := Button.new()
	reset.text = Loc.t("BTN_RESET")
	reset.custom_minimum_size = Vector2(0, 60)
	reset.pressed.connect(func() -> void: ask_confirm(Loc.t("CONFIRM_RESET"), func() -> void: reset_confirmed.emit()))
	modal_body.add_child(reset)

func _build_confirm() -> void:
	var l := Label.new()
	l.text = confirm_text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	modal_body.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var no := Button.new()
	no.text = Loc.t("BTN_CANCEL")
	no.custom_minimum_size = Vector2(0, 60)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(close_modal)
	row.add_child(no)
	var yes := Button.new()
	yes.text = Loc.t("BTN_YES")
	yes.custom_minimum_size = Vector2(0, 60)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(func() -> void:
		var cb := confirm_yes
		close_modal()
		if cb.is_valid():
			cb.call())
	row.add_child(yes)
	modal_body.add_child(row)
