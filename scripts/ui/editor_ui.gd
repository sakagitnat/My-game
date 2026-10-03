class_name EditorUI
extends CanvasLayer

# The map editor's screen: a bar on top (leave, undo, redo, scene, menu) and a palette at the bottom (tool tabs,
# the pieces of the chosen tool, brush size). Big buttons for a finger. The menu holds save, copy/paste of the map
# as text, map size and going back to the shipped map. All behaviour is in MapEditor; this only drives it.
signal leave_requested(keep: bool)
signal scene_changed(zone: String)

const TOOL_KEYS := {"hand": "ED_HAND", "ground": "ED_GROUND", "wall": "ED_WALL", "prop": "ED_PROPS", "land": "ED_LAND", "erase": "ED_ERASE"}
const TILE_KEYS := {SceneLayout.Tile.GRASS: "TILE_GRASS", SceneLayout.Tile.SAND: "TILE_SAND", SceneLayout.Tile.WATER: "TILE_WATER", SceneLayout.Tile.ROAD: "TILE_ROAD", SceneLayout.Tile.PAVEMENT: "TILE_PAVEMENT", SceneLayout.Tile.FLOOR: "TILE_FLOOR", SceneLayout.Tile.DIRT: "TILE_DIRT"}
const WALL_KEYS := {"wall": "WALL_WALL", "window": "WALL_WINDOW", "door": "WALL_DOOR", "low": "WALL_LOW"}
const LAND_KEYS := {".": "LAND_LOCKED", "B": "LAND_SALE", "S": "LAND_START"}

var editor: MapEditor
var root: Control
var top_bar: HBoxContainer
var palette: VBoxContainer
var items_row: HBoxContainer
var brush_row: HBoxContainer
var note: Label
var modal: PanelContainer
var modal_body: VBoxContainer
var undo_button: Button
var redo_button: Button
var scene_button: Button
var tool_buttons: Dictionary = {}
var note_time := 0.0

func setup(map_editor: MapEditor) -> void:
	editor = map_editor
	layer = 12
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.build()
	add_child(root)
	_build_top()
	_build_palette()
	_build_modal()
	editor.changed.connect(refresh)
	refresh()

func _btn(text: String, size: Vector2, toggle: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_NONE
	return b

func _build_top() -> void:
	top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 10
	top_bar.offset_top = 10
	top_bar.offset_right = -10
	root.add_child(top_bar)
	var leave := _btn(Loc.t("ED_LEAVE"), Vector2(120, 60))
	leave.pressed.connect(func() -> void: _open_leave())
	top_bar.add_child(leave)
	undo_button = _btn(Loc.t("ED_UNDO"), Vector2(100, 60))
	undo_button.pressed.connect(func() -> void: editor.undo())
	top_bar.add_child(undo_button)
	redo_button = _btn(Loc.t("ED_REDO"), Vector2(100, 60))
	redo_button.pressed.connect(func() -> void: editor.redo())
	top_bar.add_child(redo_button)
	scene_button = _btn("", Vector2(170, 60))
	scene_button.pressed.connect(_switch_scene)
	top_bar.add_child(scene_button)
	note = Label.new()
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", UiTheme.GOLD)
	top_bar.add_child(note)
	var menu := _btn(Loc.t("ED_MENU"), Vector2(110, 60))
	menu.pressed.connect(_open_menu)
	top_bar.add_child(menu)

func _build_palette() -> void:
	palette = VBoxContainer.new()
	palette.add_theme_constant_override("separation", 6)
	palette.anchor_left = 0.0
	palette.anchor_right = 1.0
	palette.anchor_top = 1.0
	palette.anchor_bottom = 1.0
	palette.grow_vertical = Control.GROW_DIRECTION_BEGIN
	palette.offset_left = 10
	palette.offset_right = -10
	palette.offset_bottom = -10
	root.add_child(palette)
	var panel := PanelContainer.new()
	palette.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	inner.add_child(tabs)
	for t in MapEditor.TOOLS:
		var b := _btn(Loc.t(TOOL_KEYS[t]), Vector2(0, 58), true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _choose_tool(t))
		tabs.add_child(b)
		tool_buttons[t] = b
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 76)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(scroll)
	items_row = HBoxContainer.new()
	items_row.add_theme_constant_override("separation", 6)
	scroll.add_child(items_row)
	brush_row = HBoxContainer.new()
	brush_row.add_theme_constant_override("separation", 6)
	inner.add_child(brush_row)

func _build_modal() -> void:
	modal = PanelContainer.new()
	modal.visible = false
	modal.set_anchors_preset(Control.PRESET_CENTER)
	modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	modal.grow_vertical = Control.GROW_DIRECTION_BOTH
	modal.custom_minimum_size = Vector2(420, 0)
	root.add_child(modal)
	modal_body = VBoxContainer.new()
	modal_body.add_theme_constant_override("separation", 10)
	modal.add_child(modal_body)

var _poll_timer := 0.0

func _process(delta: float) -> void:
	if note_time > 0.0:
		note_time -= delta
		if note_time <= 0.0:
			note.text = ""
	editor.flush_if_due(delta)
	_poll_timer += delta
	if _poll_timer >= 0.15:
		_poll_timer = 0.0
		poll_web_text_box()

func say(key: String) -> void:
	note.text = Loc.t(key)
	note_time = 3.0

# ---------------------------------------------------------------- palette

func _choose_tool(t: String) -> void:
	editor.tool = t
	if t == "ground" and editor.brush < 1:
		editor.brush = 1
	refresh()

func refresh() -> void:
	if editor == null or items_row == null:
		return
	undo_button.disabled = not editor.can_undo()
	redo_button.disabled = not editor.can_redo()
	scene_button.text = Loc.t("ZONE_RESTAURANT" if editor.zone == "restaurant" else "ZONE_FARM")
	scene_button.visible = GameState.has_farm_zone()
	for t in tool_buttons:
		tool_buttons[t].set_pressed_no_signal(t == editor.tool)
		tool_buttons[t].text = Loc.t(TOOL_KEYS[t])
	for child in items_row.get_children():
		items_row.remove_child(child)
		child.queue_free()
	for child in brush_row.get_children():
		brush_row.remove_child(child)
		child.queue_free()
	match editor.tool:
		"ground":
			for t in TILE_KEYS:
				_item(Loc.t(TILE_KEYS[t]), editor.tile == t, func() -> void: editor.tile = t)
			_brush_buttons()
		"wall":
			for k in WALL_KEYS:
				_item(Loc.t(WALL_KEYS[k]), editor.wall_kind == k, func() -> void: editor.wall_kind = k)
		"prop":
			for k in Catalog.OBSTACLES:
				_item(Loc.t(Catalog.OBSTACLES[k].name), editor.prop_id == k, func() -> void: editor.prop_id = k)
			for k in GameState.placeables_in(editor.zone):
				if Catalog.is_top(k):
					continue   # things for tables are placed in the game, not painted into a map
				_item(Loc.t(Catalog.PLACEABLES[k].name), editor.prop_id == k, func() -> void: editor.prop_id = k)
		"land":
			for k in LAND_KEYS:
				_item(Loc.t(LAND_KEYS[k]), editor.land_label == k, func() -> void: editor.land_label = k)
		"erase":
			_item(Loc.t("ED_ERASE_ITEM"), not editor.erase_walls, func() -> void: editor.erase_walls = false)
			_item(Loc.t("ED_ERASE_WALL"), editor.erase_walls, func() -> void: editor.erase_walls = true)
		"hand":
			var hint := Label.new()
			hint.text = Loc.t("ED_HAND_HINT")
			items_row.add_child(hint)
	if editor.tool == "ground":
		brush_row.visible = true
	else:
		brush_row.visible = false

func _item(text: String, selected: bool, action: Callable) -> void:
	var b := _btn(text, Vector2(120, 64), true)
	b.set_pressed_no_signal(selected)
	b.pressed.connect(func() -> void:
		action.call()
		refresh())
	items_row.add_child(b)

func _brush_buttons() -> void:
	var l := Label.new()
	l.text = Loc.t("ED_BRUSH")
	brush_row.add_child(l)
	for n in [1, 2, 3, 4]:
		var b := _btn("%d" % n, Vector2(64, 52), true)
		b.set_pressed_no_signal(editor.brush == n)
		b.pressed.connect(func() -> void:
			editor.brush = n
			refresh())
		brush_row.add_child(b)

func _switch_scene() -> void:
	editor.set_zone("farm" if editor.zone == "restaurant" else "restaurant")
	scene_changed.emit(editor.zone)
	refresh()

# ---------------------------------------------------------------- menus

func _clear_modal() -> void:
	for child in modal_body.get_children():
		modal_body.remove_child(child)
		child.queue_free()

func _title(text: String) -> void:
	var t := Label.new()
	t.text = text
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", UiTheme.GOLD)
	modal_body.add_child(t)

func _modal_button(text: String, action: Callable) -> Button:
	var b := _btn(text, Vector2(0, 60))
	b.pressed.connect(action)
	modal_body.add_child(b)
	return b

func close_modal() -> void:
	modal.visible = false

func _open_menu() -> void:
	_clear_modal()
	_title(Loc.t("ED_MENU"))
	_modal_button(Loc.t("ED_SAVE"), func() -> void:
		close_modal()
		say("ED_SAVED" if editor.save() else "ED_SAVE_FAILED"))
	_modal_button(Loc.t("ED_EXPORT"), _export)
	_modal_button(Loc.t("ED_IMPORT"), _import)
	_modal_button(Loc.t("ED_SIZE"), _open_size)
	_modal_button(Loc.t("ED_RESET_MAP"), func() -> void:
		editor.reset_to_shipped()
		close_modal()
		say("ED_RESET_DONE"))
	_modal_button(Loc.t("BTN_CLOSE"), close_modal)
	modal.visible = true

func _open_size() -> void:
	_clear_modal()
	_title(Loc.t("ED_SIZE"))
	var info := Label.new()
	var blocks := editor.current().cells / WorldGrid.PARCEL
	info.text = Loc.t("ED_SIZE_FMT") % [blocks.x, blocks.y, editor.current().cells.x, editor.current().cells.y]
	modal_body.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	modal_body.add_child(grid)
	for pair in [["ED_WIDER", Vector2i(1, 0)], ["ED_NARROWER", Vector2i(-1, 0)], ["ED_LONGER", Vector2i(0, 1)], ["ED_SHORTER", Vector2i(0, -1)]]:
		var b := _btn(Loc.t(pair[0]), Vector2(190, 60))
		b.pressed.connect(func() -> void:
			if not editor.resize_by(pair[1]):
				say("ED_SIZE_LIMIT")
			_open_size())
		grid.add_child(b)
	_modal_button(Loc.t("BTN_CLOSE"), close_modal)
	modal.visible = true

func _open_leave() -> void:
	_clear_modal()
	_title(Loc.t("ED_LEAVE_TITLE"))
	var l := Label.new()
	l.text = Loc.t("ED_LEAVE_TEXT")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(380, 0)
	modal_body.add_child(l)
	_modal_button(Loc.t("ED_KEEP"), func() -> void: leave_requested.emit(true))
	_modal_button(Loc.t("ED_DISCARD"), func() -> void: leave_requested.emit(false))
	_modal_button(Loc.t("BTN_CANCEL"), close_modal)
	modal.visible = true

# ---------------------------------------------------------------- map as text

func _export() -> void:
	var text := editor.export_text()
	close_modal()
	if OS.has_feature("web"):
		_web_text_box(text, false)
	else:
		DisplayServer.clipboard_set(text)
		say("ED_COPIED")

func _import() -> void:
	close_modal()
	if OS.has_feature("web"):
		_web_text_box("", true)
	else:
		_apply_import(DisplayServer.clipboard_get())

func _apply_import(text: String) -> void:
	say("ED_IMPORTED" if editor.import_text(text) == "ok" else "ED_IMPORT_BAD")

# On the web the text lives in an HTML text box laid over the game (the iPad keyboard and paste only work there).
var _web_box_import := false
var _web_box_open := false

func _web_text_box(text: String, for_import: bool) -> void:
	_web_box_import = for_import
	_web_box_open = true
	var d := {"text": text, "import": for_import, "title": Loc.t("ED_IMPORT" if for_import else "ED_EXPORT"),
		"hint": Loc.t("ED_IMPORT_HINT" if for_import else "ED_EXPORT_HINT"), "go": Loc.t("ED_LOAD" if for_import else "ED_COPY"), "close": Loc.t("BTN_CLOSE")}
	var js := """(function(d){
var old=document.getElementById('salvora_textbox');if(old)old.remove();
var f=document.createElement('div');f.id='salvora_textbox';f.className='salvora-in';
f.style.cssText='position:fixed;left:0;top:0;right:0;bottom:0;z-index:20;overflow:auto;display:flex;justify-content:center;align-items:flex-start;padding:5vh 12px;box-sizing:border-box;background:rgba(0,0,0,.5);font-family:sans-serif;';
f.innerHTML='<div style="width:min(640px,100%%);box-sizing:border-box;background:#1b2428;border:3px solid #c58a50;border-radius:14px;padding:16px;color:#f4ece0;display:flex;flex-direction:column;gap:8px;">'
+'<div id="tb_title" style="font-size:24px;"></div><div id="tb_hint" style="font-size:16px;opacity:.85;"></div>'
+'<textarea id="tb_text" spellcheck="false" style="font-size:14px;height:38vh;box-sizing:border-box;padding:8px;border:1px solid #4a5560;border-radius:8px;background:#11171b;color:#f4ece0;outline:0;font-family:monospace;"></textarea>'
+'<button id="tb_go" style="font-size:20px;height:56px;border:1px solid #6f7d8a;border-radius:10px;background:#2c3b41;color:#f4ece0;"></button>'
+'<button id="tb_close" style="font-size:18px;height:50px;border:1px solid #6f7d8a;border-radius:10px;background:#2c3b41;color:#f4ece0;"></button></div>';
document.body.appendChild(f);
var t=document.getElementById('tb_text');t.value=d.text;
document.getElementById('tb_title').textContent=d.title;document.getElementById('tb_hint').textContent=d.hint;
document.getElementById('tb_go').textContent=d.go;document.getElementById('tb_close').textContent=d.close;
window.__tb={done:0,text:'',closed:0};
document.getElementById('tb_go').addEventListener('click',function(){
 if(d.import){window.__tb.text=t.value;window.__tb.done=1;}
 else{t.focus();t.select();try{navigator.clipboard.writeText(t.value);}catch(e){try{document.execCommand('copy');}catch(e2){}}}});
document.getElementById('tb_close').addEventListener('click',function(){window.__tb.closed=1;});
if(!d.import){setTimeout(function(){t.focus();t.select();},50);}
})(%s)""" % JSON.stringify(d)
	JavaScriptBridge.eval(js)
	set_process(true)

func poll_web_text_box() -> void:
	if not _web_box_open or not OS.has_feature("web"):
		return
	var res = JavaScriptBridge.eval("(function(){var s=window.__tb||{};var o=JSON.stringify({done:s.done||0,text:s.text||'',closed:s.closed||0});if(s.done)s.done=0;return o;})()", true)
	var r = JSON.parse_string(str(res)) if res != null else null
	if not (r is Dictionary):
		return
	if int(r.get("done", 0)) == 1:
		_close_web_box()
		_apply_import(str(r.get("text", "")))
	elif int(r.get("closed", 0)) == 1:
		_close_web_box()

func _close_web_box() -> void:
	_web_box_open = false
	JavaScriptBridge.eval("(function(){var f=document.getElementById('salvora_textbox');if(f)f.remove();})()")
