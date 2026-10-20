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
	check(world.loading != null, "a loading message shows while the world is built")
	for i in 30:                                      # the world is built over a few frames
		if world.ready_3d:
			break
		await process_frame
	check(world.ready_3d and world.loading == null, "the world is built and the message is gone")
	var nature = world.nature_mesh
	gs.restaurant._spawn()                            # a customer arriving changes the game ...
	gs.changed.emit()
	for i in 30:
		await process_frame
	check(world.nature_mesh == nature, "... but does not rebuild the scenery")
	gs.restaurant.customers.clear()
	gs.restaurant.counter.clear()
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

	# tapping a seated guest cooks their dish, and once it is ready, serves it
	gs.clock_override = 50000.0
	check(gs.place_object("restaurant", Vector2i(27, 14), "rest_stove_01") == "ok", "a stove for the kitchen")
	gs.inventory.add("wheat", 4)
	check(gs.restaurant._spawn(), "a guest sits down")
	var guest: Dictionary = gs.restaurant.customers[0]
	guest.dish = "wheat_porridge"
	await process_frame
	var animal = world.guests[guest.id]
	animal.path.clear()                               # skip the walk to the seat
	animal.position = world._seat_of(guest)
	world.target = animal.position
	world._place_camera()
	await process_frame
	var bubble: Node3D = world.labels[guest.id]
	check(bubble.visible and (bubble.get_node("State") as Label3D).text.contains(loc_t(gs, "ORDER_TAP_COOK")), "the bubble says to tap to cook")
	var on_guest: Vector2 = world.camera.unproject_position(animal.position + Vector3(0, 0.7, 0))
	check(world.guest_at(on_guest) == guest.id, "a tap on the guest finds them")
	check(world.guest_at(on_guest + Vector2(400, 0)) == -1, "a tap beside them does not")
	world._tap(on_guest)
	check(gs.restaurant.is_cooking("wheat_porridge"), "the tap starts their dish on the stove")
	gs.clock_override += 100.0
	gs.restaurant.tick(0.0)
	check(gs.restaurant.counter.has("wheat_porridge"), "the dish is ready on the counter")
	var coins_before: int = gs.coins
	world._tap(on_guest)
	check(gs.coins > coins_before and gs.restaurant.customers.is_empty(), "a second tap serves it and they pay")

	# while placing, a drag that starts on the ghost moves it (and does not pan the view)
	world.game.start_placement("rest_table_small_01")
	world.tap_ground(Vector3(18.0, 0, 12.0))
	var ghost_before: Vector2i = world.game.ghost_cell
	var target_before: Vector3 = world.target
	var from: Vector2 = world.camera.unproject_position(Vector3(18.2, 0, 12.2))   # grabbed off its middle: it keeps the grip
	var to: Vector2 = world.camera.unproject_position(Vector3(20.2, 0, 13.2))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	world._unhandled_input(press)
	var move := InputEventMouseMotion.new()
	move.position = to
	move.relative = to - from
	world._unhandled_input(move)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = to
	world._unhandled_input(release)
	check(world.game.ghost_cell == ghost_before + Vector2i(4, 2), "dragging the ghost moves it: %s -> %s" % [ghost_before, world.game.ghost_cell])
	check(world.target == target_before, "and leaves the view where it was")
	world.game.cancel_placement()

	world.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: world3d")
	else:
		printerr("%d check(s) failed" % failures)
	quit(failures)

func loc_t(_gs, key: String) -> String:
	return root.get_node("/root/Loc").t(key)
