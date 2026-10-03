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
	gs.save_path = "user://test_salvora_scenes.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.autosave = false
	gs.ask_names = false
	gs.restaurant_active = false
	gs.spawn_obstacles = true
	gs.reset()
	gs.level = 10
	gs.coins = 5000

	# The restaurant map: sea along the bottom-left edge only, a country road across the top, the shop near the corner
	var lay: SceneLayout = gs.layout_for("restaurant")
	var g: WorldGrid = gs.grid("restaurant")
	check(lay.cells == Vector2i(72, 54) and g.size == lay.cells and lay.area == "any", "the main map is 72x54 cells and takes every item")
	check(lay.parcels.size() == 9 and lay.parcels[0].length() == 12, "12x9 land blocks")
	var water := {"top": 0, "bottom": 0, "left_upper": 0, "right_upper": 0}
	for i in range(72):
		if lay.tile_at(Vector2i(i, 0)) == SceneLayout.Tile.WATER:
			water.top += 1
		if lay.tile_at(Vector2i(i, 53)) == SceneLayout.Tile.WATER:
			water.bottom += 1
	for i in range(0, 38):
		if lay.tile_at(Vector2i(0, i)) == SceneLayout.Tile.WATER:
			water.left_upper += 1
		if lay.tile_at(Vector2i(71, i)) == SceneLayout.Tile.WATER:
			water.right_upper += 1
	check(water.bottom == 72 and water.top == 0 and water.left_upper == 0 and water.right_upper == 0, "the sea is on the bottom-left edge only")
	check(lay.tile_at(Vector2i(36, 50)) == SceneLayout.Tile.WATER and lay.tile_at(Vector2i(18, 12)) == SceneLayout.Tile.FLOOR, "water in front, floor in the shop")
	check(not lay.is_solid(Vector2i(36, 50)) and lay.is_solid(Vector2i(18, 12)) and lay.is_solid(Vector2i(36, 30)), "water is not solid, land is")
	check(lay.coast_segments().size() > 40, "there is a shoreline along the front")
	var road_ok := true
	for x in range(72):
		for y in range(0, 4):
			road_ok = road_ok and lay.is_road(Vector2i(x, y))
	check(road_ok and lay.is_solid(Vector2i(0, 2)) and lay.is_solid(Vector2i(71, 2)), "the country road runs across the top, flush to the border, off both sides")
	var floor_ok := true
	for y in range(6, 18):
		for x in range(12, 24):
			floor_ok = floor_ok and lay.tile_at(Vector2i(x, y)) == SceneLayout.Tile.FLOOR
	check(floor_ok and lay.tile_at(Vector2i(11, 10)) != SceneLayout.Tile.FLOOR and lay.tile_at(Vector2i(24, 10)) != SceneLayout.Tile.FLOOR, "the shop floor is 12x12 cells")
	check(lay.wall_at(Vector2i(17, 6), "n") == "door" and lay.wall_at(Vector2i(18, 6), "n") == "door" and lay.wall_at(Vector2i(15, 6), "n") == "wall", "the door is in the north wall, facing the road")
	check(lay.wall_at(Vector2i(13, 6), "n") == "window" and lay.wall_at(Vector2i(12, 8), "w") == "window" and lay.wall_at(Vector2i(12, 11), "w") == "wall", "walls and windows at the back")
	check(lay.wall_at(Vector2i(24, 10), "w") == "low" and lay.wall_at(Vector2i(15, 18), "n") == "low", "low walls on the open sides")
	check(lay.walls.size() == 48, "the shop has 48 wall pieces")
	check(lay.tile_at(Vector2i(17, 4)) == SceneLayout.Tile.PAVEMENT and lay.tile_at(Vector2i(18, 5)) == SceneLayout.Tile.PAVEMENT, "a paved path joins the road to the door")
	check(lay.starts.size() == 8 and g.owned_parcels.size() == 8 and g.bought_count() == 0, "the four shop blocks and the four farm blocks are owned at the start")
	check(gs.start_cell() == Vector2i(18, 12), "the camera starts in the middle of the shop")
	check(g.has_floor(Vector2i(2, 1)) == false, "the shop floor is painted tiles, not a bought style")

	# Land for sale: only the blocks marked B around the shop; never the road or the sea
	check(g.can_buy_parcel(Vector2i(1, 1)) and g.can_buy_parcel(Vector2i(4, 2)) and g.can_buy_parcel(Vector2i(2, 3)), "land next to the shop can be bought")
	check(not g.can_buy_parcel(Vector2i(2, 0)) and not g.can_buy_parcel(Vector2i(3, 8)) and not g.can_buy_parcel(Vector2i(6, 1)), "the road, the sea and locked land are not for sale")
	for p in lay.sale_parcels():
		check(lay.label_of_parcel(p) == "B", "only blocks marked B are for sale")
	check(lay.sale_parcels().size() == 31, "thirty-one blocks around the shop and the farm are for sale")
	check(gs.buy_land("restaurant", Vector2i(1, 1) * 6) == "ok" and gs.coins == 4850, "buy the block beside the shop")

	# Floors: the shop is fixed, bought land can be built over and put back
	check(gs.set_floor("restaurant", Vector2i(1, 1) * 6 + Vector2i(2, 2), true) == "ok" and gs.coins == 4790 and g.has_floor(Vector2i(1, 1)), "build a floor on a bought block")
	check(gs.set_floor("restaurant", Vector2i(1, 1) * 6, true) == "same", "already a floor")
	check(gs.set_floor("restaurant", Vector2i(1, 1) * 6, false) == "ok" and not g.has_floor(Vector2i(1, 1)) and gs.coins == 4790, "back to open ground is free")
	check(gs.set_floor("restaurant", Vector2i(18, 12), false) == "fixed", "the shop floor stays")
	check(gs.set_floor("restaurant", Vector2i(2, 3) * 6, true) == "locked", "cannot build over land you do not own")
	check(gs.set_floor("farm", Vector2i(12, 12), true) == "invalid", "no floors in the farm")
	gs.coins = 10
	check(gs.set_floor("restaurant", Vector2i(1, 1) * 6, true) == "no_coins", "a floor costs coins")
	gs.coins = 5000
	gs.set_floor("restaurant", Vector2i(1, 1) * 6, true)

	# Items only where they belong
	check(gs.check_place("restaurant", gs.start_cell(), "rest_table_small_01") == "ok", "table in the shop")
	check(gs.check_place("restaurant", gs.start_cell(), "farm_plot_01") == "ok", "farm items can be placed on the one main map")
	check(gs.check_place("restaurant", Vector2i(36, 2), "rest_table_small_01") == "area", "nothing on the road")
	check(gs.check_place("restaurant", Vector2i(36, 50), "rest_table_small_01") == "invalid", "nothing in the sea")
	check(gs.check_place("restaurant", Vector2i(2, 3) * 6 + Vector2i(3, 3), "rest_table_small_01") == "locked", "unbought land is locked")
	check(gs.check_place("restaurant", Vector2i(1, 1) * 6 + Vector2i(3, 3), "rest_table_small_01") == "ok", "tables go on bought land")

	# Obstacles are part of the map: none in the shop, on the road or in the water
	var bad := 0
	for c in g.blocked:
		if lay.tile_at(c) in [SceneLayout.Tile.FLOOR, SceneLayout.Tile.ROAD, SceneLayout.Tile.WATER] or not lay.is_solid(c):
			bad += 1
	check(bad == 0, "trees and rocks stand only on open ground")
	check(g.blocked.size() > 200, "trees and rocks lie around: %d" % g.blocked.size())

	# The farm: all grass, one starting block, every block for sale
	var farm: SceneLayout = gs.layout_for("farm")
	check(farm.cells == Vector2i(30, 30) and gs.grid("farm").owned_parcels.size() == 1, "the farm is 30x30 with one starting block")
	check(gs.farm_start_cell() == Vector2i(15, 15), "the farm camera starts in the middle")
	check(farm.sale_parcels().size() == 24 and gs.grid("farm").blocked.size() > 30, "farm blocks are for sale and trees stand about")
	check(gs.check_place("farm", Vector2i(15, 15), "farm_plot_01") == "ok" and gs.check_place("farm", Vector2i(15, 15), "rest_table_small_01") == "invalid", "farm items in the farm only")

	# Maps are data: round trip through text, painting, the smooth shoreline, and the owner's copy in user storage
	var copy := SceneLayout.from_dict(MapStore.parse(MapStore.to_text(lay)))
	check(copy.tiles == lay.tiles and copy.walls == lay.walls and copy.parcels == lay.parcels and copy.obstacles.size() == lay.obstacles.size(), "a map survives to_dict / from_dict")
	var pond := SceneLayout.blank("pond", "any", Vector2i(24, 24))
	check(pond.coast_segments().is_empty() and pond.edge_distance(Vector2i(12, 12)) == 99, "a map without water has no coast")
	pond.set_tile(Vector2i(12, 12), SceneLayout.Tile.WATER)
	pond.rebuild()
	check(pond.is_solid(Vector2i(12, 12)) == false and pond.tile_at(Vector2i(12, 12)) == SceneLayout.Tile.WATER, "a water cell is never solid")
	for y in range(10, 14):
		for x in range(10, 14):
			pond.set_tile(Vector2i(x, y), SceneLayout.Tile.WATER)
	pond.rebuild()
	check(not pond.has_land(Vector2i(11, 11)) and pond.has_land(Vector2i(6, 6)) and pond.coast_segments().size() > 6, "a pond has a smooth shore")
	check(pond.edge_distance(Vector2i(6, 6)) >= 3 and pond.edge_distance(Vector2i(11, 11)) == -1, "distance to the water")
	pond.set_wall(Vector2i(3, 3), "n", "window")
	check(pond.wall_at(Vector2i(3, 3), "n") == "window" and pond.wall_at(Vector2i(3, 3), "w") == "", "walls sit on cell edges")
	pond.set_wall(Vector2i(3, 3), "n", "")
	check(pond.walls.is_empty(), "a wall can be removed")
	pond.set_parcel_label(Vector2i(1, 1), "S")
	check(pond.starts == [Vector2i(1, 1)] and pond.start_cell() == Vector2i(9, 9), "start blocks and the start cell")
	pond.id = "restaurant"
	check(MapStore.save_user(pond) and MapStore.has_user_map("restaurant"), "an edited map is saved to user storage")
	check(MapStore.load_layout("restaurant").cells == Vector2i(24, 24) and MapStore.load_layout("restaurant", false).cells == Vector2i(72, 54), "the user copy wins; the shipped map is still there")
	MapStore.reset_user("restaurant")
	check(not MapStore.has_user_map("restaurant") and MapStore.load_layout("restaurant").cells == Vector2i(72, 54), "going back to the shipped map")

	# Floors survive saving; a saved map of another size is ignored
	gs.autosave = true
	gs.save_game()
	var saved_floor: bool = g.has_floor(Vector2i(1, 1))
	gs.reset()
	check(not gs.grid("restaurant").has_floor(Vector2i(1, 1)), "reset clears floors")
	check(gs.load_game() and gs.grid("restaurant").has_floor(Vector2i(1, 1)) == saved_floor, "floors persist")
	var f := FileAccess.open(gs.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "coins": 777, "grids": {"restaurant": {"size": [30, 30], "parcel": 6, "parcels": [[2, 2]], "start": 1, "objects": [[13, 13, "rest_table_small_01", 2, 2]]}}}))
	f.close()
	gs.reset()
	check(gs.load_game() and gs.coins == 777 and gs.grid("restaurant").objects.is_empty() and gs.grid("restaurant").owned_parcels.size() == 8, "a restaurant saved on a map of another size is replaced by the new one")
	gs.autosave = false

	# World: scene switching, the floor bubble and the placement grid
	gs.reset()
	gs.level = 10
	gs.coins = 5000
	gs.buy_land("restaurant", Vector2i(1, 1) * 6)
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	check(world.zone == "restaurant" and world.decor != null, "the world opens in the restaurant with its decor layer")
	world.camera.position = Iso.cell_to_world(gs.start_cell())
	world.camera.zoom = Vector2.ONE
	world._on_tap(Iso.cell_to_world(Vector2i(1, 1) * 6 + Vector2i(3, 3)))
	check(world.selected_land != world.NONE and world.hud.context.visible, "tapping bought land opens its bubble")
	world._on_action_pressed()
	check(gs.grid("restaurant").has_floor(Vector2i(1, 1)) and world.selected_land == world.NONE, "the bubble builds a floor")
	world._on_tap(Iso.cell_to_world(Vector2i(18, 12)))
	check(world.selected_land != world.NONE, "the shop floor has a bubble too")
	world._deselect()
	world._on_tap(Iso.cell_to_world(Vector2i(6, 2)))
	check(world.hud.message_key == "MSG_AREA_INFO", "tapping land that is not for sale says so")
	world.start_placement("rest_table_small_01")
	world.set_ghost(Vector2i(18, 12))
	await process_frame
	check(world.view.ghost_id == "rest_table_small_01" and world.placement_status() == "ok", "placing shows a ghost the decor layer can draw a grid for")
	world.set_ghost(Vector2i(36, 2))
	check(world.placement_status() == "area" and world.hud.placement_ok.disabled, "a ghost on the road is invalid")
	world.cancel_placement()
	world.hud.zone_toggled.emit()
	check(world.zone == "farm" and world.camera.position == Iso.cell_to_world(gs.farm_start_cell()), "walking to the farm centres the farm")
	world.hud.zone_toggled.emit()
	check(world.zone == "restaurant", "and back")
	world.queue_free()
	await process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: scenes (maps as data, one-sided sea, shop walls, land for sale, floors, farm, saves)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)
