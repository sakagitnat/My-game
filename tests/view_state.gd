extends SceneTree

# The contract between game code (world.gd) and graphics code (scripts/visuals/), see docs/COLLAB.md.
var failures := 0

func check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func snapshot(gs) -> Dictionary:
	var g := {}
	for z in gs.grids:
		g[z] = gs.grids[z].to_dict()
	return {"coins": gs.coins, "xp": gs.xp, "level": gs.level, "grids": g, "inventory": gs.inventory.to_dict()}

func run() -> void:
	var gs = root.get_node("/root/GameState")
	gs.restaurant_active = false
	gs.ask_names = false
	gs.use_sandbox_layouts()
	gs.spawn_obstacles = true
	gs.save_path = "user://test_salvora5.json"
	gs.autosave = false
	gs.reset()
	gs.level = 10
	gs.coins = 5000

	# Defaults mean "nothing selected" rather than cell (0, 0)
	var v := ViewState.new()
	check(v.ghost_id == "" and v.selected_origin == WorldGrid.NONE and v.selected_obstacle == WorldGrid.NONE and v.moving_origin == WorldGrid.NONE, "ViewState defaults to nothing selected")
	check(Catalog.PLACEABLES.has("farm_plot_01") and not Catalog.PLACEABLES["farm_plot_01"].has("color"), "game rules no longer carry look-only colours")
	for kind in Catalog.OBSTACLES:
		check(not Catalog.OBSTACLES[kind].has("art") and not Catalog.OBSTACLES[kind].has("scale") and ArtCatalog.obstacle(kind).has("art"), "obstacle %s: sprite data lives in ArtCatalog" % kind)
	for id in Catalog.PLACEABLES:
		check(ArtCatalog.placeable_color(id) is Color, "colour for %s" % id)
	for crop in Catalog.CROPS:
		check(ArtCatalog.crop_color(crop) is Color, "colour for crop %s" % crop)

	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_zone("farm")
	gs.place_object("farm", Vector2i(13, 13), "farm_plot_01")
	gs.interact("farm", Vector2i(13, 13), "wheat")
	gs.place_object("farm", Vector2i(15, 15), "farm_coop_01")
	world.camera.position = Iso.cell_to_world(gs.start_cell())
	world.camera.zoom = Vector2.ONE

	# world.gd keeps the view in step with what the player is doing
	world._redraw_all()
	check(world.view.zone == "farm" and world.view.ghost_id == "", "view follows the zone")
	world.start_placement("farm_fence_01")
	world.set_ghost(Vector2i(14, 16))
	check(world.view.ghost_id == "farm_fence_01" and world.view.ghost_cell == Vector2i(14, 16) and world.view.ghost_status == "ok", "ghost is mirrored into the view")
	world.set_ghost(Vector2i(13, 13))
	check(world.view.ghost_status == "occupied", "ghost status is mirrored")
	world.cancel_placement()
	check(world.view.ghost_id == "", "view clears the ghost")
	world._on_tap(Iso.cell_to_world(Vector2i(13, 13)))
	check(world.view.selected_origin == Vector2i(13, 13), "selection is mirrored")
	world._on_move_requested()
	check(world.view.moving_origin == Vector2i(13, 13) and world.view.ghost_id == "farm_plot_01", "move is mirrored")
	world.cancel_placement()
	check(world.view.moving_origin == WorldGrid.NONE, "view clears the move")

	# The renderer only reads: drawing every kind of view must not change the game
	var before := snapshot(gs)
	var spot := Vector2i.ZERO
	for c in gs.grid("farm").blocked:
		spot = c
		break
	var views := []
	for i in range(6):
		var vs := ViewState.new()
		vs.zone = "farm" if i % 2 == 0 else "restaurant"
		match i:
			0:
				vs.ghost_id = "farm_plot_01"
				vs.ghost_cell = Vector2i(14, 14)
				vs.ghost_status = "ok"
			1:
				vs.ghost_id = "rest_table_small_01"
				vs.ghost_cell = Vector2i(14, 14)
				vs.ghost_status = "occupied"
			2:
				vs.selected_origin = Vector2i(13, 13)
			3:
				vs.selected_obstacle = spot
			4:
				vs.moving_origin = Vector2i(13, 13)
				vs.ghost_id = "farm_coop_01"
				vs.ghost_cell = Vector2i(16, 16)
				vs.ghost_status = "blocked"
		views.append(vs)
	for vs in views:
		world.renderer.view = vs
		world.renderer.set_zone(vs.zone)
		world.renderer.refresh()
		await process_frame
		await process_frame
	check(snapshot(gs) == before, "rendering never changes game state")
	world.renderer.view = world.view
	world.renderer.set_zone("farm")
	await process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: view contract (ViewState defaults, mirroring, read-only renderer)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)
