extends SceneTree

# The 3D world builds from the shipped map and plays through the game's own controller: a tap on the 3D ground places a
# table, the selection follows taps, a customer shows as an animal at their seat and leaves when served.

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
	gs.restaurant_active = false
	gs.save_path = "user://test_salvora_3d.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.reset()
	gs.coins = 100000
	gs.level = 10

	var world = load("res://scenes/world3d.tscn").instantiate()
	root.add_child(world)
	for i in 5:
		await process_frame
	var meshes := 0
	for n in world.get_children():
		if n is MeshInstance3D and n.mesh != null:
			meshes += 1
	check(meshes >= 3, "ground, sea and the static world are meshes: %d" % meshes)
	check(world.chef != null and world.chef.species == "cat" and world.chef.chef, "a cat chef")
	check(world.game != null and world.game.host_3d == world and world.game.hud.in_3d, "the game's controller and HUD run under the 3D world")
	check(not world.game.renderer.visible and not world.game.decor.visible, "the 2D drawing is hidden")

	# place a table by tapping the 3D floor, as a player would
	world.game.start_placement("rest_table_small_01")
	world.tap_ground(Vector3(18.0, 0, 12.0))
	check(world.ghost_mesh.mesh != null, "the ghost shows in 3D while placing")
	check(world.game.ghost_cell == Vector2i(37, 25), "the tap moves the ghost to the tapped spot: %s" % world.game.ghost_cell)
	world.game.confirm_placement()
	check(gs.grid("restaurant").objects.values().has("rest_table_small_01"), "the table is placed")
	check(world.ghost_mesh.mesh != null, "placing goes on after a table, as in the 2D game")
	world.game.cancel_placement()                     # the Done button
	for i in 3:
		await process_frame
	check(world.ghost_mesh.mesh == null, "the ghost is gone when placing is done")

	# tapping the table selects it, tapping open ground clears the selection
	world.tap_ground(Vector3(18.0, 0, 12.0))
	check(world.game.selected_origin != WorldGrid.NONE and world.mark_mesh.mesh != null, "a tap selects the table and marks it")
	world.tap_ground(Vector3(14.0, 0, 9.0))
	check(world.game.selected_origin == WorldGrid.NONE, "a tap on the floor clears the selection")

	# a customer arrives: an animal walks to the seat; when they go, it walks away
	check(gs.restaurant._spawn(), "a customer sits down")
	await process_frame
	check(world.guests.size() == 1, "the customer shows as an animal")
	var c: Dictionary = gs.restaurant.customers[0]
	gs.restaurant.customers.clear()
	await process_frame
	check(world.guests.is_empty(), "a customer who left is no longer a guest")
	check(c.has("seat_cell"), "customers carry their seat")

	world.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: world3d")
	else:
		printerr("%d check(s) failed" % failures)
	quit(failures)
