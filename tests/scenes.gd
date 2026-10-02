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

	# Labels are known and named in both languages
	for key in SceneLayout.LABELS:
		check(loc.t(SceneLayout.LABELS[key].name) != SceneLayout.LABELS[key].name, "area name translated: %s" % key)
	loc.set_language("th")
	for key in SceneLayout.LABELS:
		check(loc.t(SceneLayout.LABELS[key].name) != SceneLayout.LABELS[key].name, "Thai area name: %s" % key)
	loc.set_language("en")

	# The restaurant scene: a seaside plot with the shop in the middle and a country road in front
	var lay: SceneLayout = gs.layout_for("restaurant")
	var g: WorldGrid = gs.grid("restaurant")
	check(lay.cells == Vector2i(48, 36) and g.size == lay.cells, "restaurant map is 48x36 cells")
	check(lay.parcel_count() * WorldGrid.PARCEL == lay.cells, "blocks fill the map")
	for key in lay.rows:
		for ch in key:
			check(SceneLayout.LABELS.has(ch), "known label %s" % ch)
	check(lay.shell == Rect2i(18, 12, 12, 12), "the shop is 12x12 cells in the middle")
	check(g.owned_parcels.size() == 4 and g.bought_count() == 0, "the shop blocks are free at the start")
	for y in range(12, 24):
		for x in range(18, 30):
			check(lay.is_solid(Vector2i(x, y)), "shop cell %d,%d is solid" % [x, y])
			break
	check(gs.start_cell() == Vector2i(24, 18), "the camera starts in the middle of the shop")
	check(g.has_floor(Vector2i(3, 2)) and g.has_floor(Vector2i(4, 3)), "the shop blocks start as indoor floor")
	check(lay.door_cells.size() == 2 and lay.door_cells[0].y == lay.shell.end.y - 1, "the door is in the front wall")
	check(not lay.is_solid(Vector2i(24, 1)) and not lay.has_land(Vector2i(24, 1)), "open sea behind the shop")
	check(lay.is_solid(Vector2i(24, 12)) and lay.is_solid(Vector2i(24, 27)), "land from the shop to the road")
	check(not lay.is_solid(Vector2i(0, 8)) and lay.is_solid(Vector2i(0, 20)), "the sea curves round both ends")
	check(lay.coast_segments().size() > 20, "there is a shoreline")
	check(lay.road == Rect2i(0, 25, 48, 4) and lay.is_road(Vector2i(0, 26)) and lay.is_road(Vector2i(47, 28)), "the country road runs across the front")
	check(lay.is_solid(Vector2i(0, 26)) and lay.is_solid(Vector2i(47, 26)), "the road reaches both sides of the scene")
	check(not lay.is_road(Vector2i(24, 18)), "the shop is not on the road")

	# Land for sale: terrace by the sea and gardens at the sides; never the road or the sea
	check(g.can_buy_parcel(Vector2i(3, 1)) and g.can_buy_parcel(Vector2i(2, 2)) and g.can_buy_parcel(Vector2i(5, 3)), "terrace and garden blocks next to the shop can be bought")
	check(not g.can_buy_parcel(Vector2i(3, 4)) and not g.can_buy_parcel(Vector2i(3, 0)) and not g.can_buy_parcel(Vector2i(2, 1)), "the road and the sea are not for sale")
	for p in lay.sale_parcels():
		check(lay.label_of_parcel(p) in ["B", "r"], "only terrace and garden are for sale")
	check(gs.buy_land("restaurant", Vector2i(3, 1) * 6) == "ok" and gs.coins == 4850, "buy the terrace block")

	# Floors: the shop is fixed, bought land can be built over and put back
	check(gs.set_floor("restaurant", Vector2i(3, 1) * 6 + Vector2i(2, 2), true) == "ok" and gs.coins == 4790 and g.has_floor(Vector2i(3, 1)), "build a floor on a bought block")
	check(gs.set_floor("restaurant", Vector2i(3, 1) * 6, true) == "same", "already a floor")
	check(gs.set_floor("restaurant", Vector2i(3, 1) * 6, false) == "ok" and not g.has_floor(Vector2i(3, 1)) and gs.coins == 4790, "back to open ground is free")
	check(gs.set_floor("restaurant", Vector2i(24, 18), false) == "fixed", "the shop floor stays")
	check(gs.set_floor("restaurant", Vector2i(2, 2) * 6, true) == "locked", "cannot build over land you do not own")
	check(gs.set_floor("restaurant", Vector2i(3, 4) * 6, true) == "invalid" and gs.set_floor("farm", Vector2i(12, 12), true) == "invalid", "no floors on the road or in the farm")
	gs.coins = 10
	check(gs.set_floor("restaurant", Vector2i(3, 1) * 6, true) == "no_coins", "a floor costs coins")
	gs.coins = 5000
	gs.set_floor("restaurant", Vector2i(3, 1) * 6, true)

	# Items only where they belong
	check(gs.check_place("restaurant", gs.start_cell(), "rest_table_small_01") == "ok", "table in the shop")
	check(gs.check_place("restaurant", gs.start_cell(), "farm_plot_01") == "invalid", "farm items do not belong in the restaurant")
	check(gs.check_place("restaurant", Vector2i(24, 26), "rest_table_small_01") == "area", "nothing on the road")
	check(gs.check_place("restaurant", Vector2i(24, 2), "rest_table_small_01") == "invalid", "nothing in the sea")
	check(gs.check_place("restaurant", Vector2i(2, 3) * 6 + Vector2i(3, 3), "rest_table_small_01") == "locked", "unbought land is locked")
	check(gs.check_place("restaurant", Vector2i(3, 1) * 6 + Vector2i(3, 3), "rest_table_small_01") == "ok", "tables go on a bought terrace")

	# Obstacles: the shop and the road are clear
	var in_shop := 0
	var on_road := 0
	for c in g.blocked:
		if lay.shell.has_point(c):
			in_shop += 1
		if lay.is_road(c):
			on_road += 1
	check(in_shop == 0 and on_road == 0, "the shop and the road are clear")
	check(g.blocked.size() > 15, "trees and rocks lie around the unbought land")

	# The farm: a plot with a beach all round, one starting block
	var farm: SceneLayout = gs.layout_for("farm")
	check(farm.cells == Vector2i(30, 30) and gs.grid("farm").owned_parcels.size() == 1, "the farm is 30x30 with one starting block")
	check(gs.farm_start_cell() == Vector2i(15, 15), "the farm camera starts in the middle")
	check(farm.sale_parcels().size() == 25 or farm.sale_parcels().size() > 15, "farm blocks are for sale")
	check(gs.check_place("farm", Vector2i(15, 15), "farm_plot_01") == "ok" and gs.check_place("farm", Vector2i(15, 15), "rest_table_small_01") == "invalid", "farm items in the farm only")

	# Floors survive saving; a saved map of another size is ignored
	gs.autosave = true
	gs.save_game()
	var saved_floor: bool = g.has_floor(Vector2i(3, 1))
	gs.reset()
	check(not gs.grid("restaurant").has_floor(Vector2i(3, 1)), "reset clears floors")
	check(gs.load_game() and gs.grid("restaurant").has_floor(Vector2i(3, 1)) == saved_floor and gs.grid("restaurant").has_floor(Vector2i(3, 2)), "floors persist")
	var f := FileAccess.open(gs.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "coins": 777, "grids": {"restaurant": {"size": [30, 30], "parcel": 6, "parcels": [[2, 2]], "start": 1, "objects": [[13, 13, "rest_table_small_01", 2, 2]]}}}))
	f.close()
	gs.reset()
	check(gs.load_game() and gs.coins == 777 and gs.grid("restaurant").objects.is_empty() and gs.grid("restaurant").owned_parcels.size() == 4, "a restaurant saved on the old 30x30 map is replaced by the new one")
	gs.autosave = false

	# World: scene switching, the floor bubble and the placement grid
	gs.reset()
	gs.level = 10
	gs.coins = 5000
	gs.buy_land("restaurant", Vector2i(3, 1) * 6)
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	check(world.zone == "restaurant" and world.decor != null, "the world opens in the restaurant with its decor layer")
	world.camera.position = Iso.cell_to_world(gs.start_cell())
	world.camera.zoom = Vector2.ONE
	world._on_tap(Iso.cell_to_world(Vector2i(3, 1) * 6 + Vector2i(3, 3)))
	check(world.selected_land != world.NONE and world.hud.context.visible, "tapping bought land opens its bubble")
	world._on_action_pressed()
	check(gs.grid("restaurant").has_floor(Vector2i(3, 1)) and world.selected_land == world.NONE, "the bubble builds a floor")
	world._on_tap(Iso.cell_to_world(Vector2i(24, 18)))
	check(world.selected_land != world.NONE, "the shop floor has a bubble too")
	world._deselect()
	world._on_tap(Iso.cell_to_world(Vector2i(1, 4) * 6 + Vector2i(2, 2)))
	check(world.hud.message_key == "MSG_AREA_INFO", "tapping the road says what it is")
	world.start_placement("rest_table_small_01")
	world.set_ghost(Vector2i(24, 18))
	await process_frame
	check(world.view.ghost_id == "rest_table_small_01" and world.placement_status() == "ok", "placing shows a ghost the decor layer can draw a grid for")
	world.set_ghost(Vector2i(24, 26))
	check(world.placement_status() == "area" and world.hud.placement_ok.disabled, "a ghost on the road is invalid")
	world.cancel_placement()
	world.hud.zone_toggled.emit()
	check(world.zone == "farm" and world.camera.position == Iso.cell_to_world(gs.farm_start_cell()), "walking to the farm centres the farm")
	world.hud.zone_toggled.emit()
	check(world.zone == "restaurant", "and back")
	world.queue_free()
	await process_frame

	# The overview map (art only): the whole island with an organic coast
	var ov := SceneLayout.overview()
	check(ov.parcel_count() == Vector2i(11, 11) and ov.cells == Vector2i(66, 66), "the overview is the 11x11 block island")
	var land := 0
	for y in range(66):
		for x in range(66):
			if ov.is_solid(Vector2i(x, y)):
				land += 1
	var frac: float = float(land) / (66 * 66)
	check(frac > 0.35 and frac < 0.7, "land covers about half of the overview")
	check(not ov.has_land(Vector2i(0, 0)) and not ov.has_land(Vector2i(65, 65)), "its corners are sea")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: scenes (restaurant shop, sea and road, land for sale, floors, areas, farm, saves, overview)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)
