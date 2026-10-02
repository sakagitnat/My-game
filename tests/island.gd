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
	loc.set_language("en")
	gs.save_path = "user://test_salvora_island.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.autosave = false
	gs.ask_names = false
	gs.restaurant_active = false
	gs.spawn_obstacles = true
	gs.layout = Island.standard()
	gs.reset()
	gs.level = 10
	gs.coins = 5000

	# The map itself
	var isl: Island = gs.layout
	check(isl.parcel_count() == Vector2i(11, 11) and isl.parcel_count() * WorldGrid.PARCEL == gs.GRID_SIZE, "11x11 blocks fill the grid")
	for y in isl.rows.size():
		check(isl.rows[y].length() == 11, "row %d has 11 blocks" % y)
		for ch in isl.rows[y]:
			check(Island.LABELS.has(ch), "known label %s" % ch)
	for key in Island.LABELS:
		check(loc.t(Island.LABELS[key].name) != Island.LABELS[key].name, "area name translated: %s" % key)
	loc.set_language("th")
	for key in Island.LABELS:
		check(loc.t(Island.LABELS[key].name) != Island.LABELS[key].name, "Thai area name: %s" % key)
	loc.set_language("en")
	var counts := {}
	for row in isl.rows:
		for ch in row:
			counts[ch] = int(counts.get(ch, 0)) + 1
	for need in ["R", "F", "P", "G", "C", "J", "M", "S", "H", "K", "O", "L", "W", "X"]:
		check(counts.has(need), "the island has %s" % need)
	check(int(counts.get("X", 0)) >= 8, "plenty of open land is kept for later")

	# Start: one restaurant block and the farm block beside it
	var g: WorldGrid = gs.grid()
	check(isl.label_of_parcel(isl.restaurant_start) == "R" and isl.label_of_parcel(isl.farm_start) == "F", "start blocks are restaurant and farm")
	check(g.is_owned(gs.start_cell()) and g.is_owned(gs.farm_start_cell()), "both start blocks are owned")
	check(g.owned_parcels.size() == 2 and g.bought_count() == 0, "two free blocks at the start")
	check(absi(isl.restaurant_start.x - isl.farm_start.x) + absi(isl.restaurant_start.y - isl.farm_start.y) == 1, "start blocks touch")
	check(WorldGrid.parcel_of(gs.start_cell()) == isl.restaurant_start, "camera starts on the restaurant")

	# Only farm and restaurant land is for sale, and only next to land the player owns
	var east: Vector2i = isl.restaurant_start + Vector2i(1, 0)
	check(g.can_buy_parcel(east) and g.can_buy_parcel(isl.farm_start + Vector2i(0, 1)), "touching restaurant/farm blocks can be bought")
	check(not g.can_buy_parcel(Vector2i(9, 9)), "a far block cannot be bought")
	check(gs.buy_land("island", east * 6) == "ok", "buy the block beside the start")
	check(isl.label_of_parcel(Vector2i(5, 5)) == "M" and not g.can_buy_parcel(Vector2i(5, 5)), "town land next to yours is not for sale")
	check(not isl.for_sale(Vector2i(2, 2)) and isl.label_of_parcel(Vector2i(2, 2)) == "W", "forest is never for sale")
	for p in isl.sale_parcels():
		check(isl.label_of_parcel(p) in ["R", "F"], "only R and F are for sale")

	# Items go only on their own kind of land
	var r_cell: Vector2i = gs.start_cell()
	var f_cell: Vector2i = gs.farm_start_cell()
	check(gs.check_place("island", r_cell, "rest_table_small_01") == "ok", "table on restaurant land")
	check(gs.check_place("island", f_cell, "rest_table_small_01") == "area", "table on farm land is refused")
	check(gs.check_place("island", f_cell, "farm_plot_01") == "ok", "plot on farm land")
	check(gs.check_place("island", r_cell, "farm_plot_01") == "area", "plot on restaurant land is refused")
	check(gs.check_place("island", Vector2i(5, 5) * 6 + Vector2i(2, 2), "farm_plot_01") == "area", "nothing on town land")
	var seam := Vector2i(isl.farm_start.x * 6 + 6, isl.restaurant_start.y * 6 + 3)  # first column of the restaurant block
	check(gs.check_place("island", seam, "farm_plot_01") == "area", "a footprint half on restaurant land is refused")
	gs.place_object("island", r_cell, "rest_table_small_01")
	var origin: Vector2i = g.origin_at(r_cell)
	check(gs.check_move("island", origin, f_cell) == "area", "moving to the wrong land is refused")
	check(gs.check_move("island", origin, r_cell + Vector2i(1, 0)) == "ok", "moving within restaurant land is fine")

	# The coast is an organic outline with open sea all around
	var land := 0
	for y in range(gs.GRID_SIZE.y):
		for x in range(gs.GRID_SIZE.x):
			if isl.is_solid(Vector2i(x, y)):
				land += 1
	var frac: float = float(land) / (gs.GRID_SIZE.x * gs.GRID_SIZE.y)
	check(frac > 0.35 and frac < 0.7, "land covers about half of the map")
	check(not isl.has_land(Vector2i(0, 0)) and not isl.has_land(Vector2i(65, 65)) and not isl.has_land(Vector2i(0, 65)) and not isl.has_land(Vector2i(65, 0)), "the corners are sea")
	check(isl.is_solid(gs.start_cell()) and isl.edge_distance(gs.start_cell()) >= 4, "the start is well inland")
	check(isl.edge_distance(Vector2i(0, 0)) == -1, "water has no edge distance")
	check(isl.coast_segments().size() > 100, "the shoreline has many pieces")
	var rows_with_land := 0
	for y in range(gs.GRID_SIZE.y):
		var first := -1
		var last := -1
		for x in range(gs.GRID_SIZE.x):
			if isl.is_solid(Vector2i(x, y)):
				if first < 0:
					first = x
				last = x
		if first >= 0:
			rows_with_land += 1
	check(rows_with_land > 30 and rows_with_land < gs.GRID_SIZE.y, "the island does not touch the map edge")
	check(gs.check_place("island", Vector2i(2, 2), "farm_plot_01") == "invalid", "nothing can be built in the water")
	var shoreline := Vector2i(-1, -1)
	for y in range(gs.GRID_SIZE.y):
		for x in range(gs.GRID_SIZE.x):
			var c := Vector2i(x, y)
			if shoreline.x < 0 and isl.has_land(c) and not isl.is_solid(c):
				shoreline = c
	check(shoreline.x >= 0, "there are shore cells that are only partly land")

	# Obstacles follow the land: forest is thick, town and start blocks are clear
	var w := 0
	var wcells := 0
	var town := 0
	var start_blocked := 0
	for c in g.blocked:
		var lab := isl.label_of_cell(c)
		if lab == "W":
			w += 1
		elif lab in ["P", "T"]:
			town += 1
		if gs.in_start_clearing(c):
			start_blocked += 1
	for y in range(gs.GRID_SIZE.y):
		for x in range(gs.GRID_SIZE.x):
			if isl.label_of_cell(Vector2i(x, y)) == "W" and gs.edge_distance(Vector2i(x, y)) >= 3:
				wcells += 1
	check(wcells > 0 and float(w) / wcells > 0.25, "the forest reserve is thick with trees")
	check(town == 0, "the plaza and paths are clear")
	check(start_blocked == 0, "the start blocks are clear")
	check(g.blocked.size() > 120, "the island has plenty of obstacles overall")

	# Tapping land that cannot be bought says what it is
	gs.autosave = false
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.camera.position = Iso.cell_to_world(gs.start_cell())
	world.camera.zoom = Vector2.ONE
	world._on_tap(Iso.cell_to_world(Vector2i(5, 5) * 6 + Vector2i(3, 3)))
	check(world.hud.message_key == "MSG_AREA_INFO" and world.hud.message_arg == "Clinic", "tapping the clinic land names it")
	world._on_tap(Iso.cell_to_world(Vector2i(1, 8) * 6 + Vector2i(3, 3)))
	check(world.hud.message_key == "MSG_AREA_INFO" and world.hud.message_arg == "Open land", "tapping reserve land names it")
	world._on_tap(Iso.cell_to_world(Vector2i(1, 5) * 6 + Vector2i(3, 3)))
	check(world.hud.modal.visible and world.hud.modal_kind == "confirm", "tapping a farm block next to yours offers to buy it")
	world.hud.close_modal()
	world.start_placement("rest_table_small_01")
	world.set_ghost(f_cell)
	check(world.placement_status() == "area" and world.hud.placement_ok.disabled, "ghost on the wrong land is invalid")
	world.cancel_placement()
	world.queue_free()
	await process_frame

	# An old save with separate restaurant and farm maps keeps the player's money but starts a fresh island
	gs.spawn_obstacles = false
	gs.reset()
	var f := FileAccess.open(gs.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "coins": 777, "level": 3, "inventory": {"items": {"wheat": 4}, "capacity": 60},
		"grids": {"restaurant": {"parcels": [[2, 2]], "parcel": 6}, "farm": {"parcels": [[2, 2]], "parcel": 6}}}))
	f.close()
	check(gs.load_game() and gs.coins == 777 and gs.level == 3, "old save keeps coins and level")
	check(gs.grid().owned_parcels.size() == 2 and gs.grid().objects.is_empty(), "old maps are replaced by a fresh island")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: island (layout, for-sale blocks, land areas, obstacles, tap info, old saves)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)
