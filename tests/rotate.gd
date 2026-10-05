extends SceneTree

# Turn buttons on the game screen: the placement bar and the selected object's bubble.
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
	gs.save_path = "user://test_salvora_rotate.json"
	gs.autosave = false
	gs.reset()
	gs.level = 10
	gs.coins = 5000
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame

	world.start_placement("rest_stove_01")
	check(world.hud.placement_rotate.visible, "a stove can be turned while placing")
	world.set_ghost(Vector2i(28, 28))
	world.rotate_ghost()
	world._sync_view()
	check(world.placing_facing == 1 and world.view.ghost_facing == 1, "the turn button turns the ghost")
	world.confirm_placement()
	var origin: Vector2i = gs.grid("restaurant").origin_at(Vector2i(28, 28))
	check(origin != WorldGrid.NONE and gs.grid("restaurant").facing_at(origin) == 1, "the placed stove keeps its turn")
	world.cancel_placement()
	check(world.placing_facing == 0, "leaving placement resets the turn")

	world.start_placement("rest_table_small_01")
	check(not world.hud.placement_rotate.visible, "a table shows no turn button")
	world.rotate_ghost()
	check(world.placing_facing == 0, "a table cannot be turned")
	world.cancel_placement()

	world._select(origin)
	check(world._context_info(origin).can_rotate, "the stove bubble offers a turn")
	world._on_rotate_requested()
	origin = world.view.selected_origin   # a turn keeps the middle, so the top-left unit moves and the selection follows it
	check(gs.grid("restaurant").facing_at(origin) == 2, "the bubble turns the stove")
	var before: Dictionary = gs.grid("restaurant").to_dict()
	var saved := JSON.parse_string(JSON.stringify(before)) as Dictionary
	gs.grid("restaurant").load_dict(saved)
	check(gs.grid("restaurant").facing_at(origin) == 2, "the turn survives a save")

	if failures == 0:
		print("PASS: rotate (placing, bubble, save)")
	else:
		print("%d check(s) failed" % failures)
	quit(1 if failures > 0 else 0)
