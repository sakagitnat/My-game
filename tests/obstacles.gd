extends SceneTree

var failures := 0

func check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var gs = root.get_node("/root/GameState")
	var loc = root.get_node("/root/Loc")
	var assets = root.get_node("/root/Assets")
	loc.set_language("en")
	gs.save_path = "user://test_salvora4.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.autosave = false
	gs.spawn_obstacles = true
	gs.reset()
	gs.level = 10

	# Noise and scatter are deterministic and respect the clear areas
	check(Noise2D.hash2(3, 4, 5) == Noise2D.hash2(3, 4, 5) and Noise2D.hash2(3, 4, 5) != Noise2D.hash2(4, 3, 5), "hash is stable and position dependent")
	var v := Noise2D.value(1.37, 8.9, 2)
	check(v >= 0.0 and v <= 1.0, "value noise stays in 0..1")
	for z in Catalog.ZONES:
		var g: WorldGrid = gs.grid(z)
		check(g.blocked.size() > 40, "%s island has plenty of obstacles" % z)
		var in_clear := false
		var on_beach := false
		for c in g.blocked:
			if gs.CLEAR_AREA.has_point(c):
				in_clear = true
			if gs.edge_distance(c) < 3:
				on_beach = true
		check(not in_clear, "%s: middle of the starting block is clear" % z)
		check(not on_beach, "%s: the beach is clear" % z)
	var farm_layout: Dictionary = gs.grid("farm").blocked.duplicate()
	var rest_layout: Dictionary = gs.grid("restaurant").blocked.duplicate()
	check(farm_layout != rest_layout, "zones get different layouts")
	gs.reset()
	check(gs.grid("farm").blocked == farm_layout and gs.grid("restaurant").blocked == rest_layout, "layout is the same every new game")
	for kind in gs.grid("farm").blocked.values():
		check(Catalog.OBSTACLES.has(kind), "known obstacle kind %s" % kind)

	# Blocking and clearing (use a controlled layout)
	gs.spawn_obstacles = false
	gs.reset()
	gs.level = 10
	var g: WorldGrid = gs.grid("farm")
	g.blocked[Vector2i(14, 14)] = "tree"
	g.blocked[Vector2i(12, 17)] = "rock"
	g.blocked[Vector2i(20, 14)] = "bush"
	check(gs.check_place("farm", Vector2i(13, 13), "farm_plot_01") == "blocked", "obstacle inside a footprint blocks placing")
	check(gs.place_object("farm", Vector2i(13, 13), "farm_plot_01") == "blocked" and gs.coins == 500, "blocked placement is free and does nothing")
	check(gs.check_place("farm", Vector2i(15, 13), "farm_plot_01") == "ok", "free spot next to it is fine")
	gs.place_object("farm", Vector2i(15, 13), "farm_plot_01")
	check(gs.check_move("farm", Vector2i(15, 13), Vector2i(14, 14)) == "blocked", "cannot move onto an obstacle")
	check(gs.clear_obstacle("farm", Vector2i(20, 14)) == "locked", "cannot clear on land you do not own")
	check(gs.clear_obstacle("farm", Vector2i(1, 1)) == "empty", "nothing to clear on an empty cell")
	gs.coins = 10
	check(gs.clear_obstacle("farm", Vector2i(14, 14)) == "no_coins" and g.blocked.has(Vector2i(14, 14)) and gs.coins == 10, "clearing needs coins")
	gs.coins = 100
	var xp_before: int = gs.xp
	check(gs.clear_obstacle("farm", Vector2i(14, 14)) == "ok", "clear a tree")
	check(gs.coins == 70 and gs.inventory.count("wood") == 1 and gs.xp == xp_before + 2 and not g.blocked.has(Vector2i(14, 14)), "tree costs 30, gives wood and 2 XP")
	check(gs.check_place("farm", Vector2i(13, 13), "farm_plot_01") == "ok", "cleared ground can be built on")
	check(gs.clear_obstacle("farm", Vector2i(12, 17)) == "ok" and gs.inventory.count("stone") == 1 and gs.coins == 50, "rock costs 20 and gives stone")
	g.blocked[Vector2i(16, 16)] = "bush"
	check(gs.clear_obstacle("farm", Vector2i(16, 16)) == "ok" and gs.coins == 40 and gs.inventory.total() == 2, "bush costs 10 and gives nothing")
	g.blocked[Vector2i(13, 16)] = "tree"
	gs.inventory.capacity = gs.inventory.total()
	check(gs.clear_obstacle("farm", Vector2i(13, 16)) == "ok" and gs.inventory.count("wood") == 1, "a full barn does not stop clearing, the item is just lost")
	gs.inventory.capacity = 60
	check(Catalog.ITEMS.has("wood") and Catalog.ITEMS.has("stone"), "wood and stone are sellable")

	# Persistence
	g.blocked[Vector2i(14, 15)] = "rock"
	gs.autosave = true
	gs.save_game()
	var saved_blocked: Dictionary = g.blocked.duplicate()
	gs.reset()
	check(gs.load_game() and gs.grid("farm").blocked == saved_blocked, "cleared and remaining obstacles persist")
	var legacy: Dictionary = gs.grid("farm").to_dict()
	legacy.erase("obstacles")
	var f := FileAccess.open(gs.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "coins": 5, "grids": {"farm": legacy}}))
	f.close()
	gs.spawn_obstacles = true
	gs.reset()
	gs.grid("farm").blocked.clear()
	check(gs.load_game() and gs.grid("farm").blocked.size() > 40, "a save from before obstacles gets a fresh scatter")
	for c in gs.grid("farm").blocked:
		check(not gs.grid("farm").occupied.has(c), "scatter never lands on an object")
		break
	gs.spawn_obstacles = false

	# World + HUD
	gs.autosave = false
	gs.reset()
	gs.level = 10
	var gw: WorldGrid = gs.grid("restaurant")
	gw.blocked[Vector2i(16, 16)] = "tree"
	gw.blocked[Vector2i(20, 14)] = "rock"
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	check(is_instance_valid(world.signs) and world.signs.layer == "signs" and world.terrain.layer == "ground", "terrain and sign layers exist")
	check(world.sea.material is ShaderMaterial and (world.sea.material as ShaderMaterial).shader != null, "sea shader is attached")
	world.camera.position = Iso.cell_to_world(gs.start_cell())
	world.camera.zoom = Vector2.ONE
	world._on_tap(Iso.cell_to_world(Vector2i(16, 16)))
	check(world.selected_obstacle == Vector2i(16, 16) and world.hud.context.visible, "tapping an owned obstacle opens its bubble")
	var move_buttons := 0
	for b in world.hud.context_body.find_children("*", "Button", true, false):
		if b.text == loc.t("BTN_MOVE") or b.text.begins_with("Sell"):
			move_buttons += 1
	check(move_buttons == 0, "obstacle bubble has no Move or Sell")
	world.start_placement("rest_table_small_01")
	world.set_ghost(Vector2i(16, 16))
	check(world.placement_status() == "blocked" and world.hud.placement_ok.disabled, "ghost over an obstacle is invalid")
	world.cancel_placement()
	world._on_tap(Iso.cell_to_world(Vector2i(16, 16)))
	world._on_action_pressed()
	check(not gw.blocked.has(Vector2i(16, 16)) and gs.coins == 470 and world.selected_obstacle == WorldGrid.NONE, "bubble action clears the tree")
	world._on_tap(Iso.cell_to_world(Vector2i(20, 14)))
	check(world.hud.modal.visible and world.hud.modal_kind == "confirm" and world.selected_obstacle == WorldGrid.NONE, "tapping an obstacle on unowned land offers to buy the block instead")
	world.hud.close_modal()
	check(assets.DIRS.has("obstacles"), "asset loader searches the obstacles folder")
	world.queue_free()
	await process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: obstacles (scatter, blocking, clearing, saves, tap UI, backdrop nodes)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)
