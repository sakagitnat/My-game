extends SceneTree

# The 3D preview builds from the shipped map: ground, sea, the cat chef, seats for guests, and samples while the shop is empty.

var failures := 0

func check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var gs = root.get_node("/root/GameState")
	gs.ask_names = false
	gs.autosave = false
	gs.save_path = "user://test_salvora_3d.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.reset()

	var world = load("res://scenes/world3d.tscn").instantiate()
	root.add_child(world)
	for i in 10:
		await process_frame
	var meshes := 0
	for n in world.get_children():
		if n is MeshInstance3D and n.mesh != null:
			meshes += 1
	check(meshes >= 3, "ground, sea and the static world are meshes: %d" % meshes)
	check(world.chef != null and world.chef.species == "cat" and world.chef.chef, "a cat chef")
	check(not world.demo_objects.is_empty(), "an empty shop and garden show samples")
	check(world.seats.size() >= 2, "the sample tables give seats for guests")
	check(world.get_node_or_null("/root").get_child_count() > 0, "the scene is in the tree")
	# guests come in over time
	world._guest_timer = 0.0
	for i in 3:
		await process_frame
	check(world.guests.size() == 1, "a guest walks in")
	world.queue_free()
	await process_frame

	# with the player's own table, no sample furniture is drawn
	gs.coins = 100000
	gs.level = 10
	var shop := Vector2i(18, 12) * Iso.SUB
	check(gs.place_object("restaurant", shop, "rest_table_small_01") == "ok", "place a table")
	world = load("res://scenes/world3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var sample_tables := 0
	for d in world.demo_objects:
		if d[0] == "rest_table_small_01":
			sample_tables += 1
	check(sample_tables == 0, "no sample tables once the player has one")
	check(world.seats.size() == 2, "the player's table has two seats")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: world3d")
	else:
		printerr("%d check(s) failed" % failures)
	quit(failures)
