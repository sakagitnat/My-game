extends SceneTree

# Small things that stand on tables (vases): their own layer, carried with the table, sold with it.
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
	gs.save_path = "user://test_salvora_tabletop.json"
	gs.autosave = false
	gs.reset()
	gs.level = 10
	gs.coins = 1000
	var g: WorldGrid = gs.grid("restaurant")
	var small := "rest_vase_small_01"
	var large := "rest_vase_large_01"

	check(Catalog.is_top(small) and Catalog.is_top(large) and not Catalog.is_top("rest_table_small_01") and Catalog.is_surface("rest_table_small_01"), "vases are for tables, a table carries them")
	check(gs.place_object("restaurant", Vector2i(27, 27), small) == "no_surface" and gs.coins == 1000, "a vase needs a table under it, and costs nothing when refused")
	check(gs.place_object("restaurant", Vector2i(27, 27), "rest_table_small_01") == "ok", "place a table")
	var coins_after_table: int = gs.coins
	check(gs.place_object("restaurant", Vector2i(29, 28), large) == "no_surface", "a big vase may not hang over the table edge")
	check(gs.place_object("restaurant", Vector2i(27, 27), large) == "ok" and g.tops.size() == 1, "a big vase fits on the table (1.5 cells wide, 1 deep)")
	check(gs.place_object("restaurant", Vector2i(27, 27), large) == "occupied" and gs.place_object("restaurant", Vector2i(28, 28), small) == "occupied", "and blocks the units under it")
	coins_after_table = gs.coins
	check(gs.place_object("restaurant", Vector2i(26, 27), small) == "ok" and gs.coins == coins_after_table - 10 and g.tops.size() == 2, "a small vase goes on the free unit")
	check(g.objects.size() == 1 and g.top_origin_at(Vector2i(26, 27)) == Vector2i(26, 27) and g.origin_at(Vector2i(26, 27)) == Vector2i(26, 27), "the vase is in its own layer: the table keeps its floor")
	check(gs.place_object("restaurant", Vector2i(26, 27), small) == "occupied", "two vases cannot share a unit")
	check(gs.place_object("restaurant", Vector2i(33, 27), "rest_stove_01") == "ok", "floor things are not bothered by the layer above")

	# Moving
	check(gs.check_move("restaurant", Vector2i(26, 27), Vector2i(26, 28), true) == "ok", "a vase may be judged against others only")
	check(gs.check_move("restaurant", Vector2i(26, 27), Vector2i(24, 24), true) == "no_surface", "a vase cannot be moved off the table")
	check(gs.check_move("restaurant", Vector2i(30, 30), Vector2i(26, 26), true) == "empty", "nothing to move where no vase stands")
	check(gs.move_object("restaurant", Vector2i(26, 27), Vector2i(26, 28), true) == "ok" and g.tops.has(Vector2i(26, 28)) and not g.tops.has(Vector2i(26, 27)), "a vase moves along the table, free of charge")
	check(gs.place_object("restaurant", Vector2i(26, 27), small) == "ok" and g.tops.size() == 3, "the next unit is free: small things sit side by side")
	var table_before := g.tops.size()
	var coins_before: int = gs.coins

	# The table carries them
	gs.coins = 5000
	check(gs.check_move("restaurant", Vector2i(26, 27), Vector2i(29, 31)) == "ok", "the table can move")
	check(gs.move_object("restaurant", Vector2i(26, 27), Vector2i(29, 31)) == "ok", "move the table")
	check(g.tops.size() == table_before and g.tops.has(Vector2i(29, 31)) and g.tops.has(Vector2i(28, 32)) and g.tops.has(Vector2i(28, 31)) and not g.tops.has(Vector2i(26, 27)), "its vases moved with it")
	check(g.origin_at(Vector2i(28, 31)) == Vector2i(28, 31) and g.top_occupied.size() == 1 + 1 + 4, "both layers follow the move")

	# Saving
	var saved: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2 := WorldGrid.new(g.size)
	check(g2.load_dict(saved) and g2.tops == g.tops and g2.top_occupied == g.top_occupied, "vases are saved")
	var no_tops: Dictionary = saved.duplicate()
	no_tops.erase("tops")
	check(WorldGrid.new(g.size).load_dict(no_tops), "a save without the layer still loads")

	# Storing: a vase leaves the table for the storage; a table takes what stands on it along
	var tops_now := g.tops.size()
	var vase_at: Vector2i = g.tops.keys()[0]
	var vase_id: String = g.tops[vase_at]
	var coins_a: int = gs.coins
	check(gs.store_object("restaurant", vase_at, true) == "ok" and gs.coins == coins_a and g.tops.size() == tops_now - 1 and g.objects.size() == 2 and gs.stash_count(vase_id) == 1, "storing a vase leaves the table and pays nothing")
	var remaining: Array = g.tops.values().duplicate()
	var coins_b: int = gs.coins
	check(gs.store_object("restaurant", Vector2i(29, 31)) == "ok" and gs.coins == coins_b and g.tops.is_empty() and g.top_occupied.is_empty(), "storing the table stores what stands on it")
	check(gs.stash_count("rest_table_small_01") == 1 and gs.stash_total() == tops_now + 1, "all of it is in the storage")

	# On screen
	gs.reset()
	gs.level = 10
	gs.coins = 1000
	gs.place_object("restaurant", Vector2i(27, 27), "rest_table_small_01")
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.camera.position = Iso.cell_to_world(gs.start_cell())
	world.camera.zoom = Vector2.ONE
	world.start_placement(small)
	world.set_ghost(Vector2i(24, 24))
	check(world.placement_status() == "no_surface" and world.hud.placement_ok.disabled and not world.hud.placement_rotate.visible, "the ghost refuses a spot with no table")
	world.set_ghost(Vector2i(27, 27))
	check(world.placement_status() == "ok", "and accepts one over a table")
	world.confirm_placement()
	check(gs.grid("restaurant").tops.size() == 1, "confirm puts the vase down")
	world.cancel_placement()
	await process_frame
	world._on_tap(Iso.unit_corner(Vector2i(27, 27)) + Vector2(8, 8))
	check(world.selected_top and world.selected_origin == Vector2i(27, 27) and world.hud.context.visible, "tapping the vase selects the vase, not the table under it")
	world._sync_view()
	check(world.view.selected_top, "the selection is mirrored")
	world._on_move_requested()
	check(world.moving_top and world.placing_id == small and world.moving_origin == Vector2i(27, 27), "moving a vase starts placement mode")
	world.set_ghost(Vector2i(28, 28))
	check(world.placement_status() == "ok", "the ghost may sit on another unit of the table")
	world.confirm_placement()
	check(gs.grid("restaurant").tops.has(Vector2i(28, 28)) and gs.grid("restaurant").tops.size() == 1, "the vase moved")
	world._on_tap(Iso.unit_corner(Vector2i(28, 28)) + Vector2(8, 8))
	world._on_store_requested()
	check(gs.grid("restaurant").tops.is_empty() and not gs.grid("restaurant").objects.is_empty() and gs.stash_count(small) == 1, "storing the vase leaves the table")
	world._on_tap(Iso.unit_corner(Vector2i(27, 27)) + Vector2(8, 8))
	check(not world.selected_top and world.selected_origin == Vector2i(26, 27), "with no vase, the same tap selects the table")
	world.queue_redraw()
	await process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: tabletop (layer, moving with the table, saving, storing, taps)")
	else:
		print("%d check(s) failed" % failures)
	quit(1 if failures > 0 else 0)
