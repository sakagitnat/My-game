extends SceneTree

# The storage: furniture taken off the floor is kept (never sold on the spot), placed again for free, sold only by choice.
var failures := 0

func check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var gs = root.get_node("/root/GameState")
	gs.restaurant_active = false
	gs.ask_names = false
	gs.use_sandbox_layouts()
	gs.spawn_obstacles = false
	gs.save_path = "user://test_salvora_storage.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.autosave = false
	gs.reset()
	gs.level = 10
	gs.coins = 1000
	var table := "rest_table_small_01"
	var vase := "rest_vase_small_01"
	var g: WorldGrid = gs.grid("restaurant")

	check(gs.stash_total() == 0 and gs.store_object("restaurant", Vector2i(27, 27)) == "empty", "nothing to store where nothing stands")
	check(gs.place_object("restaurant", Vector2i(27, 27), table) == "ok" and gs.coins == 970, "buy a table")
	var xp_before: int = gs.xp
	check(gs.store_object("restaurant", Vector2i(28, 28)) == "ok" and g.objects.is_empty() and gs.stash_count(table) == 1 and gs.coins == 970, "storing keeps the piece and pays nothing")
	check(gs.check_place("restaurant", Vector2i(27, 27), table, 0, true) == "ok", "it can be placed again from the storage")
	check(gs.place_object("restaurant", Vector2i(27, 27), table, 0, true) == "ok" and gs.coins == 970 and gs.xp == xp_before and gs.stash_total() == 0 and g.objects.size() == 1, "placing from the storage is free, gives no XP and empties it")
	check(gs.place_object("restaurant", Vector2i(35, 27), table, 0, true) == "no_stock" and gs.coins == 970, "an empty storage places nothing")

	# Selling is a separate choice
	check(gs.store_object("restaurant", Vector2i(27, 27)) == "ok" and gs.stash_sell_value(table) == 15, "a stored table is worth half its price")
	check(gs.sell_stashed(table) == 15 and gs.coins == 985 and gs.stash_total() == 0, "selling from the storage pays half and removes it")
	check(gs.sell_stashed(table) == 0 and gs.sell_stashed("nothing") == 0 and gs.coins == 985, "nothing to sell, nothing paid")

	# A table takes its vases into the storage with it and they come back out one at a time
	gs.place_object("restaurant", Vector2i(27, 27), table)
	gs.place_object("restaurant", Vector2i(27, 27), vase)
	gs.place_object("restaurant", Vector2i(28, 27), vase)
	var coins: int = gs.coins
	check(gs.store_object("restaurant", Vector2i(27, 27)) == "ok" and gs.stash_count(vase) == 2 and gs.stash_count(table) == 1 and gs.coins == coins and g.tops.is_empty(), "a stored table takes what stands on it along")
	check(gs.place_object("restaurant", Vector2i(27, 27), vase, 0, true) == "no_surface", "a stored vase still needs a table")
	gs.place_object("restaurant", Vector2i(27, 27), table, 0, true)
	check(gs.place_object("restaurant", Vector2i(27, 27), vase, 0, true) == "ok" and gs.stash_count(vase) == 1 and gs.coins == coins, "vases come out of the storage onto a table for free")

	# Storing throws away what a thing was making
	gs.place_object("restaurant", Vector2i(31, 27), "rest_stove_01")
	var stove: Vector2i = g.origin_at(Vector2i(31, 27))
	check(not gs.store_loses_state("restaurant", stove), "an idle stove loses nothing")
	g.states[stove] = {"dish": "omelet", "t": 1.0}
	check(gs.store_loses_state("restaurant", stove) and gs.store_object("restaurant", stove) == "ok" and g.states.is_empty() and gs.stash_count("rest_stove_01") == 1, "a busy stove is stored without its dish")

	# Saving
	gs.autosave = true
	gs.save_game()
	gs.reset()
	check(gs.stash_total() == 0, "a new game starts with an empty storage")
	check(gs.load_game() and gs.stash_count(vase) == 1 and gs.stash_count("rest_stove_01") == 1, "the storage is saved")
	gs.autosave = false

	# On screen
	gs.reset()
	gs.level = 10
	gs.coins = 1000
	gs.stash[table] = 1
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.camera.position = Iso.cell_to_world(gs.start_cell())
	world.camera.zoom = Vector2.ONE
	world.hud.refresh()
	check(world.hud.storage_button.text == Loc_t(world, "BTN_STORAGE") % 1, "the storage button shows how many pieces it holds")
	world.hud.open_modal("storage")
	check(world.hud.modal_kind == "storage" and world.hud.modal_body.find_children("*", "Button", true, false).size() >= 3, "the storage lists each piece with Place and Sell")
	world.hud.close_modal()
	world.hud.stash_item_picked.emit(table)
	check(world.placing_id == table and world.placing_from_stash, "Place in the storage starts placing for free")
	world.set_ghost(Vector2i(27, 27))
	check(world.placement_status() == "ok", "the ghost is valid on free land")
	world.confirm_placement()
	check(g_of(gs).objects.size() == 1 and gs.coins == 1000 and gs.stash_total() == 0 and world.placing_id == "", "the last piece out ends placement mode without charging")
	world._on_tap(Iso.unit_corner(Vector2i(27, 27)) + Vector2(8, 8))
	world._on_store_requested()
	check(g_of(gs).objects.is_empty() and gs.stash_count(table) == 1 and gs.coins == 1000, "the Store button puts it back at once, no question asked")
	world.hud.open_modal("storage")
	var sell_btn: Button
	for b in world.hud.modal_body.find_children("*", "Button", true, false):
		if b.text.begins_with(Loc_t(world, "BTN_SELL_OBJ").split("%")[0]):
			sell_btn = b
	check(sell_btn != null, "the storage offers Sell on each piece")
	sell_btn.pressed.emit()
	check(world.hud.modal_kind == "confirm" and gs.stash_count(table) == 1 and gs.coins == 1000, "selling asks first and nothing is sold yet")
	world.hud.confirm_yes.call()
	check(gs.stash_total() == 0 and gs.coins == 1015, "after the player agrees it is sold for half")
	world.queue_free()
	await process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: storage (store, place free, sell by choice, saving, buttons)")
	else:
		print("%d check(s) failed" % failures)
	quit(1 if failures > 0 else 0)

func g_of(gs) -> WorldGrid:
	return gs.grid("restaurant")

func Loc_t(world, key: String) -> String:
	return root.get_node("/root/Loc").t(key)
