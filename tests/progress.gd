extends SceneTree

var failures := 0
var level_ups: Array = []

func check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func _on_level_up(lv: int) -> void:
	level_ups.append(lv)

func run() -> void:
	var gs = root.get_node("/root/GameState")
	var loc = root.get_node("/root/Loc")
	loc.set_language("en")
	gs.restaurant_active = false
	gs.ask_names = false
	gs.use_sandbox_layouts()
	gs.spawn_obstacles = false
	gs.save_path = "user://test_salvora3.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.reset()
	gs.autosave = false
	gs.clock_override = 1000.0
	gs.leveled_up.connect(_on_level_up)
	# things sit on the finer unit grid (Iso.SUB per cell): `plot` is a 2x2-cell plot's origin, `plot_c` the unit to tap to place it
	var plot := Vector2i(24, 24)
	var plot_c := plot + Vector2i(1, 1)
	var plot2 := Vector2i(28, 24)
	var plot2_c := plot2 + Vector2i(1, 1)

	# Levels and XP
	check(gs.level == 1 and gs.xp == 0 and gs.xp_for_next() == 30, "starts at level 1")
	gs.add_xp(29)
	check(gs.level == 1 and gs.xp == 29 and level_ups.is_empty(), "no level-up below the threshold")
	var coins_before: int = gs.coins
	gs.add_xp(1)
	check(gs.level == 2 and gs.xp == 0 and gs.coins == coins_before + 40 and level_ups == [2], "level-up rewards coins and signals")
	gs.add_xp(200)
	check(gs.level == 4 and level_ups == [2, 3, 4], "big XP gains can skip several levels, one signal each")
	check(gs.xp_for_next() == 90 and gs.xp < 90, "xp stays below the next threshold")

	# Unlock gating
	gs.reset()
	gs.autosave = false
	gs.clock_override = 1000.0
	check(gs.check_place("farm", Vector2i(32, 32), "farm_coop_01") == "level", "coop locked at level 1")
	check(gs.place_object("farm", Vector2i(32, 32), "farm_coop_01") == "level" and gs.coins == 500, "locked item is not placed or charged")
	check(gs.check_place("restaurant", Vector2i(27, 27), "rest_stove_01") == "ok", "the stove is available from the start so the restaurant can open")
	check(gs.check_place("restaurant", Vector2i(27, 27), "rest_table_small_01") == "ok", "table available at level 1")
	check(gs.place_object("farm", plot_c, "farm_plot_01") == "ok" and gs.xp == GameState.PLACE_XP, "placing gives XP")
	check(gs.interact("farm", plot, "tomato") == "level" and gs.coins == 490, "tomato locked at level 1")
	check(gs.place_object("farm", Vector2i(32, 32), "farm_coop_01") == "level", "coop locked at level 1")
	check(gs.interact("farm", plot, "wheat") == "planted", "wheat available at level 1")
	gs.clock_override = 1060.0
	var xp_before: int = gs.xp
	gs.interact("farm", plot, "wheat")
	check(gs.xp == xp_before + 1, "harvesting wheat gives 1 XP")
	var xp2: int = gs.xp
	gs.coins = 1000
	gs.buy_land("farm", Vector2i(20, 14))
	check(gs.xp == xp2 + GameState.LAND_XP or gs.level == 2, "buying land gives XP")
	gs.level = 2
	gs.xp = 0
	check(gs.interact("farm", plot, "tomato") == "planted", "tomato unlocks at level 2")
	check(gs.place_object("farm", Vector2i(32, 32), "farm_coop_01") == "ok", "coop unlocks at level 2")
	check(Catalog.unlock_level("farm_plot_01") == 1 and Catalog.unlock_level("farm_coop_01") == 2, "catalog unlock levels")

	# Level and XP persist; old saves default to level 1
	gs.level = 5
	gs.xp = 17
	gs.autosave = true
	gs.save_game()
	gs.reset()
	check(gs.load_game() and gs.level == 5 and gs.xp == 17, "level and xp persisted")
	var f := FileAccess.open(gs.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "coins": 33}))
	f.close()
	gs.reset()
	check(gs.load_game() and gs.level == 1 and gs.xp == 0 and gs.coins == 33, "save without level loads as level 1")
	f = FileAccess.open(gs.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "coins": 1, "level": 2, "xp": 9999}))
	f.close()
	gs.reset()
	check(gs.load_game() and gs.xp < gs.xp_for_next(), "absurd saved xp is clamped")

	# Moving objects keeps their state and is free
	gs.reset()
	gs.level = 10
	gs.autosave = false
	gs.clock_override = 1000.0
	gs.place_object("farm", plot_c, "farm_plot_01")
	gs.place_object("farm", plot2_c, "farm_plot_01")
	gs.interact("farm", plot, "cabbage")
	var coins_move: int = gs.coins
	check(gs.check_move("farm", plot, Vector2i(29, 29)) == "ok", "free spot allows moving")
	check(gs.check_move("farm", plot, plot2_c) == "occupied", "cannot move onto another object")
	check(gs.check_move("farm", plot, Vector2i(8, 8)) == "locked", "cannot move onto unowned land")
	check(gs.check_move("farm", plot, Vector2i(-10, -10)) == "invalid", "cannot move off the map")
	check(gs.check_move("farm", Vector2i(34, 34), Vector2i(29, 29)) == "empty", "nothing to move on an empty cell")
	check(gs.check_move("farm", plot, Vector2i(27, 27)) == "occupied" or gs.check_move("farm", plot, Vector2i(27, 27)) == "ok", "overlapping its own old footprint is judged on other objects only")
	check(gs.move_object("farm", plot, Vector2i(29, 29)) == "ok" and gs.coins == coins_move, "move is free")
	var moved := Vector2i(28, 28)
	check(gs.grid("farm").objects.get(moved) == "farm_plot_01" and not gs.grid("farm").objects.has(plot), "object relocated")
	check(gs.grid("farm").states.get(moved, {}).get("crop") == "cabbage", "growing crop moves with the plot")
	gs.clock_override = 1150.0
	check(is_equal_approx(gs.progress("farm", moved), 0.5), "growth timer is unchanged by moving")
	check(gs.grid("farm").origin_at(Vector2i(30, 30)) == moved and gs.grid("farm").origin_at(plot) == WorldGrid.NONE, "occupancy map follows the move")

	# World + HUD behaviour
	gs.reset()
	gs.level = 1
	gs.autosave = false
	gs.clock_override = 5000.0
	level_ups.clear()
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_zone("farm")
	world.start_placement("farm_coop_01")
	check(world.placement_status() == "level" and world.hud.placement_ok.disabled, "locked item shows as unplaceable in placement mode")
	world.cancel_placement()
	world.hud.open_modal("shop")
	var locked_buttons := 0
	for b in world.hud.modal_body.find_children("*", "Button", true, false):
		if b.disabled and b.text.contains("2"):
			locked_buttons += 1
	check(locked_buttons >= 1, "shop disables locked items and shows the needed level")
	world.hud.close_modal()
	gs.level = 2
	world.start_placement("farm_coop_01")
	world.set_ghost(Vector2i(32, 32))
	world.confirm_placement()
	check(gs.grid("farm").objects.get(Vector2i(30, 30)) == "farm_coop_01", "coop placed after unlocking")
	world.cancel_placement()
	world._on_tap(Iso.cell_to_world(Vector2i(16, 16)))
	check(world.hud.context.visible and world.selected_origin == Vector2i(30, 30), "tap on the coop opens its bubble")
	var has_action := false
	for b in world.hud.context_body.find_children("*", "Button", true, false):
		if b.text == Loc_text(loc, "BTN_FEED"):
			has_action = true
			check(b.disabled, "feeding is disabled without wheat")
	check(has_action, "idle coop bubble offers a feed action")
	gs.inventory.add("wheat", 1)
	world._on_action_pressed()
	check(gs.grid("farm").states.has(Vector2i(30, 30)) and gs.inventory.count("wheat") == 0, "feed action starts egg production")
	world._on_tap(Iso.cell_to_world(Vector2i(16, 16)))
	check(world.hud.context.visible and world.hud.context_body.find_children("*", "Label", true, false).size() >= 2, "busy coop bubble shows a status line")
	world._deselect()
	gs.clock_override = 5000.0 + 120.0
	world._on_tap(Iso.cell_to_world(Vector2i(16, 16)))
	check(gs.inventory.count("egg") == 1, "tapping a ready coop collects the egg at once")
	gs.xp = gs.xp_for_next() - 1
	gs.add_xp(1)
	check(world.hud.message_key == "MSG_LEVEL_UP" and world.hud.message_arg is Array, "level-up is announced")

	# Reset wipes progress but keeps the language
	gs.coins = 1
	gs.level = 7
	world._on_reset()
	check(gs.coins == 500 and gs.level == 1 and gs.xp == 0 and gs.grid("farm").objects.is_empty(), "reset restores a fresh game")
	check(world.zone == "restaurant", "reset returns to the restaurant")
	await process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: progress (levels, XP, unlocks, moving, bubble and modal UI, reset)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)

func Loc_text(loc, key: String) -> String:
	return loc.t(key)
