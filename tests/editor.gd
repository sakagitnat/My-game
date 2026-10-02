extends SceneTree

var failures := 0

func check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func _world_at(c: Vector2i, off: Vector2 = Vector2.ZERO) -> Vector2:
	return Iso.cell_to_world_f(Vector2(c) + off)

func run() -> void:
	var gs = root.get_node("/root/GameState")
	var loc = root.get_node("/root/Loc")
	loc.set_language("en")
	gs.save_path = "user://test_salvora_editor.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	MapStore.reset_user("restaurant")
	MapStore.reset_user("farm")
	gs.autosave = false
	gs.ask_names = false
	gs.restaurant_active = false
	gs.spawn_obstacles = true
	gs.load_default_layouts()
	gs.reset()
	gs.level = 10
	gs.coins = 5000

	# Edge picking: the nearest face of the cell under a point
	var e := SceneLayout.nearest_edge(Vector2(5.4, 5.0))
	check(e.cell == Vector2i(6, 5) and e.edge == "w", "a point near the east face picks the west face of the next cell")
	e = SceneLayout.nearest_edge(Vector2(5.0, 4.6))
	check(e.cell == Vector2i(5, 5) and e.edge == "n", "near the north face")
	e = SceneLayout.nearest_edge(Vector2(5.0, 5.45))
	check(e.cell == Vector2i(5, 6) and e.edge == "n", "near the south face picks the north face of the cell below")
	e = SceneLayout.nearest_edge(Vector2(4.6, 5.1))
	check(e.cell == Vector2i(5, 5) and e.edge == "w", "near the west face")
	check(abs(Iso.world_to_cell_f(Iso.cell_to_world_f(Vector2(7.25, 3.5))).x - 7.25) < 0.001, "world and cell coordinates round trip")

	# Editing copies, not the shipped maps
	var editor_script = load("res://scripts/world/map_editor.gd")
	var ed = editor_script.new()
	var shipped = gs.layout_for("restaurant")
	ed.begin("restaurant")
	var lay = ed.current()
	check(lay != shipped and gs.layout_for("restaurant") == lay and lay.tiles == shipped.tiles, "the editor works on a copy that the game uses meanwhile")

	# Ground
	var grass_cell := Vector2i(6, 20)
	check(lay.tile_at(grass_cell) == SceneLayout.Tile.GRASS, "starts as grass")
	ed.tool = "ground"
	ed.tile = SceneLayout.Tile.WATER
	ed.begin_stroke()
	check(ed.apply_at(_world_at(grass_cell)), "painting water changes the tile")
	check(not ed.apply_at(_world_at(grass_cell)), "painting the same again changes nothing")
	ed.end_stroke()
	check(lay.tile_at(grass_cell) == SceneLayout.Tile.WATER and ed.can_undo(), "the water is there and can be undone")
	ed.undo()
	check(lay.tile_at(grass_cell) == SceneLayout.Tile.GRASS and ed.can_redo(), "undo puts the grass back")
	ed.redo()
	check(lay.tile_at(grass_cell) == SceneLayout.Tile.WATER, "redo")
	ed.undo()
	ed.brush = 3
	ed.tile = SceneLayout.Tile.SAND
	ed.begin_stroke()
	ed.apply_at(_world_at(Vector2i(10, 20)))
	ed.end_stroke()
	var sand := 0
	for y in range(19, 22):
		for x in range(9, 12):
			if lay.tile_at(Vector2i(x, y)) == SceneLayout.Tile.SAND:
				sand += 1
	check(sand == 9, "a 3x3 brush paints nine cells")
	ed.brush = 1
	# a stroke across several cells is one undo step
	ed.tile = SceneLayout.Tile.DIRT
	var steps_before: int = ed._undo.size()
	ed.begin_stroke()
	for x in range(20, 26):
		ed.apply_at(_world_at(Vector2i(x, 30)))
	ed.end_stroke()
	check(ed._undo.size() == steps_before + 1 and lay.tile_at(Vector2i(25, 30)) == SceneLayout.Tile.DIRT, "a drag is one undo step")
	ed.begin_stroke()
	ed.end_stroke()
	check(ed._undo.size() == steps_before + 1, "a stroke that changes nothing leaves no undo step")

	# Water takes trees away and the smooth shoreline follows
	ed.tool = "prop"
	ed.prop_id = "tree"
	ed.begin_stroke()
	check(ed.apply_at(_world_at(Vector2i(8, 22))), "plant a tree on grass")
	check(not ed.apply_at(_world_at(Vector2i(8, 22))), "not twice on the same cell")
	check(not ed.apply_at(_world_at(Vector2i(36, 50))), "not in the water")
	check(not ed.apply_at(_world_at(Vector2i(36, 2))), "not on the road")
	check(not ed.apply_at(_world_at(Vector2i(18, 12))), "not on the shop floor")
	ed.end_stroke()
	check(gs.grid("restaurant").blocked.get(Vector2i(8, 22), "") == "tree", "the tree appears in the scene")
	ed.tool = "ground"
	ed.tile = SceneLayout.Tile.WATER
	ed.begin_stroke()
	ed.brush = 2
	ed.apply_at(_world_at(Vector2i(8, 22)))
	ed.end_stroke()
	ed.brush = 1
	check(not gs.grid("restaurant").blocked.has(Vector2i(8, 22)), "painting water over a tree removes it")
	ed.undo()

	# Objects need room and the right kind of ground
	ed.tool = "prop"
	ed.prop_id = "rest_table_small_01"
	ed.begin_stroke()
	check(ed.apply_at(_world_at(Vector2i(16, 12))), "put a table in the shop")
	check(not ed.apply_at(_world_at(Vector2i(16, 12))), "not on top of another")
	check(not ed.apply_at(_world_at(Vector2i(36, 2))), "not on the road")
	ed.end_stroke()
	check(gs.grid("restaurant").objects.size() == 1, "the table is an object of the scene")
	ed.prop_id = "farm_plot_01"
	ed.begin_stroke()
	check(not ed.apply_at(_world_at(Vector2i(14, 10))), "a farm item does not belong in the restaurant")
	ed.end_stroke()

	# Walls
	ed.tool = "wall"
	ed.wall_kind = "window"
	ed.begin_stroke()
	check(ed.apply_at(_world_at(Vector2i(30, 30), Vector2(0.05, -0.45))), "draw a window on a cell edge")
	check(not ed.apply_at(_world_at(Vector2i(30, 30), Vector2(0.05, -0.45))), "not twice")
	ed.end_stroke()
	check(lay.wall_at(Vector2i(30, 30), "n") == "window", "the window is on the north face")
	ed.tool = "erase"
	ed.erase_walls = true
	ed.begin_stroke()
	check(ed.apply_at(_world_at(Vector2i(30, 30), Vector2(0.05, -0.45))), "erase it")
	ed.end_stroke()
	check(lay.wall_at(Vector2i(30, 30), "n") == "", "the wall is gone")
	ed.erase_walls = false
	ed.begin_stroke()
	check(ed.apply_at(_world_at(Vector2i(17, 13))), "erase items removes the table")
	ed.end_stroke()
	check(gs.grid("restaurant").objects.is_empty(), "the table is gone from the scene")

	# Land blocks
	ed.tool = "land"
	ed.land_label = "S"
	var block := Vector2i(8, 3)
	ed.begin_stroke()
	check(ed.apply_at(_world_at(block * 6 + Vector2i(3, 3))), "mark a block as owned from the start")
	ed.end_stroke()
	check(lay.starts.size() == 5 and gs.grid("restaurant").owned_parcels.has(block), "it is owned in the scene")
	ed.land_label = "."
	ed.begin_stroke()
	ed.apply_at(_world_at(block * 6 + Vector2i(3, 3)))
	ed.end_stroke()
	check(lay.starts.size() == 4 and not gs.grid("restaurant").owned_parcels.has(block), "and locked again")

	# Size
	check(lay.cells == Vector2i(72, 54), "72x54 before resizing")
	check(ed.resize_by(Vector2i(1, 0)) and lay.cells == Vector2i(78, 54) and lay.parcels[0].length() == 13, "one block wider")
	check(lay.tile_at(Vector2i(36, 50)) == SceneLayout.Tile.WATER and lay.tile_at(Vector2i(75, 20)) == SceneLayout.Tile.GRASS, "old ground kept, new ground is grass")
	check(gs.grid("restaurant").size == Vector2i(78, 54), "the scene grid follows")
	check(ed.resize_by(Vector2i(-2, 0)) and lay.cells == Vector2i(66, 54), "two blocks narrower")
	check(lay.wall_at(Vector2i(72, 10), "w") == "", "walls beyond the new edge are dropped")
	var steps := 0
	while ed.resize_by(Vector2i(0, 1)):
		steps += 1
	check(steps == 7 and not ed.resize_by(Vector2i(0, 1)), "the map stops growing at 16 blocks")
	while ed.resize_by(Vector2i(-1, 0)):
		pass
	check(lay.cells.x == 18 and not ed.resize_by(Vector2i(-1, 0)), "and stops shrinking at 3 blocks")
	ed.undo()
	for i in range(40):
		ed.undo()
	check(lay.cells == Vector2i(72, 54), "undo walks all the way back")

	# Text out and in
	ed.tool = "ground"
	ed.tile = SceneLayout.Tile.DIRT
	ed.begin_stroke()
	ed.apply_at(_world_at(Vector2i(3, 30)))
	ed.end_stroke()
	var text: String = ed.export_text()
	var parsed_size: Array = MapStore.parse(text).get("size", [])
	check(parsed_size.size() == 2 and int(parsed_size[0]) == 72 and int(parsed_size[1]) == 54, "the map exports as JSON text")
	ed.undo()
	check(lay.tile_at(Vector2i(3, 30)) == SceneLayout.Tile.GRASS, "undone")
	check(ed.import_text(text) == "ok" and lay.tile_at(Vector2i(3, 30)) == SceneLayout.Tile.DIRT, "pasting the text brings the map back")
	check(ed.import_text("not json") == "invalid" and ed.import_text('{"size": [7, 7], "tiles": []}') == "invalid", "bad text is refused")
	check(ed.import_text(JSON.stringify({"size": [30, 30], "tiles": ["g".repeat(30)]})) == "ok" and lay.cells == Vector2i(30, 30) and lay.id == "restaurant" and lay.area == "restaurant", "a map of another size loads and keeps the scene's id")
	ed.undo()

	# Save, keep and discard
	check(ed.save() and MapStore.has_user_map("restaurant"), "saving writes the owner's copy")
	ed.finish(true)
	check(MapStore.load_layout("restaurant").tile_at(Vector2i(3, 30)) == SceneLayout.Tile.DIRT, "a kept edit is what loads next time")
	MapStore.reset_user("restaurant")
	gs.load_default_layouts()
	gs.reset()
	var ed2 = editor_script.new()
	ed2.begin("restaurant")
	ed2.tool = "ground"
	ed2.tile = SceneLayout.Tile.DIRT
	ed2.begin_stroke()
	ed2.apply_at(_world_at(Vector2i(3, 30)))
	ed2.end_stroke()
	ed2.finish(false)
	check(gs.layout_for("restaurant").tile_at(Vector2i(3, 30)) == SceneLayout.Tile.GRASS and not MapStore.has_user_map("restaurant"), "a discarded edit leaves the shipped map")
	var ed3 = editor_script.new()
	ed3.begin("restaurant")
	ed3.tool = "ground"
	ed3.tile = SceneLayout.Tile.DIRT
	ed3.begin_stroke()
	ed3.apply_at(_world_at(Vector2i(3, 30)))
	ed3.end_stroke()
	ed3.reset_to_shipped()
	check(ed3.current().tile_at(Vector2i(3, 30)) == SceneLayout.Tile.GRASS, "the menu can bring the shipped map back")
	ed3.finish(false)

	# The editor screen on the world scene
	gs.load_default_layouts()
	gs.reset()
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.hud.edit_map_requested.emit()
	check(world.hud.modal.visible and world.hud.modal_kind == "confirm", "the menu asks before editing")
	world.hud.confirm_yes.call()
	await process_frame
	check(world.editor != null and world.editor_ui != null and not world.hud.visible and world.view.edit_mode, "editing hides the game screen and turns the grid on")
	var ui = world.editor_ui
	var tabs: Array = ui.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.toggle_mode and b.text == "Walls")
	check(tabs.size() == 1, "there is a Walls tab")
	tabs[0].pressed.emit()
	check(world.editor.tool == "wall" and world.view.edit_tool == "" or world.editor.tool == "wall", "choosing a tab changes the tool")
	var kinds: Array = ui.items_row.get_children().map(func(b: Button) -> String: return b.text)
	check(kinds == ["Wall", "Window", "Door", "Low wall"], "the wall pieces are listed")
	ui._choose_tool("ground")
	check(ui.items_row.get_child_count() == 7 and ui.brush_row.visible, "seven ground kinds and a brush size")
	ui._choose_tool("prop")
	var prop_names: Array = ui.items_row.get_children().map(func(b: Button) -> String: return b.text)
	check(prop_names.has("Tree") and prop_names.has("Table") and not prop_names.has("Plot"), "trees and the restaurant's items are listed")
	ui._choose_tool("land")
	await process_frame
	world._sync_view()
	check(world.view.edit_tool == "land", "the decor layer is told which tool is active")
	world.editor.begin_stroke()
	world.editor.tool = "ground"
	world.editor.tile = SceneLayout.Tile.DIRT
	world.editor.apply_at(_world_at(Vector2i(3, 30)))
	world.editor.end_stroke()
	check(ui.undo_button.disabled == false, "undo is available after an edit")
	ui.scene_button.pressed.emit()
	check(world.zone == "farm" and world.editor.zone == "farm", "the scene button switches to the farm")
	ui.scene_button.pressed.emit()
	ui._open_leave()
	check(ui.modal.visible, "leaving asks to keep or discard")
	ui.leave_requested.emit(false)
	await process_frame
	check(world.editor == null and world.hud.visible and gs.layout_for("restaurant").tile_at(Vector2i(3, 30)) == SceneLayout.Tile.GRASS, "discarding returns to the game with the old map")
	world.queue_free()
	await process_frame

	MapStore.reset_user("restaurant")
	MapStore.reset_user("farm")
	gs.load_default_layouts()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: editor (tools, undo, size, text, save/discard, editor screen)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)
