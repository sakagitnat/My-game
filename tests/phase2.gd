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
	gs.restaurant_active = false
	gs.ask_names = false
	gs.use_sandbox_layouts()
	gs.spawn_obstacles = false
	gs.save_path = "user://test_salvora2.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.reset()
	gs.level = 10
	gs.autosave = false
	gs.clock_override = 1000.0
	# things sit on the finer unit grid (Iso.SUB per cell); a placement is given by the unit its footprint is centred on
	var plot := Vector2i(24, 24)            # origin of a 2x2-cell plot
	var plot_c := plot + Vector2i(1, 1)     # the unit to tap to place it there
	var plot2 := Vector2i(28, 24)           # origin of a 1-cell fence (a fence is centred on its own origin)
	var plot2_c := Vector2i(29, 25)         # centre unit of a second plot
	var coop_origin := Vector2i(30, 30)
	var coop := coop_origin + Vector2i(2, 2)

	check(Catalog.crop_stage(0.0) == 1 and Catalog.crop_stage(0.4) == 2 and Catalog.crop_stage(0.7) == 3 and Catalog.crop_stage(1.0) == 4, "crop stages")

	# Plots only exist once placed; planting is rejected elsewhere
	check(gs.interact("farm", plot, "wheat") == "invalid", "no plot yet")
	check(gs.place_object("farm", plot_c, "farm_plot_01") == "ok" and gs.coins == 490, "place plot")
	check(gs.interact("farm", plot, "bogus") == "invalid", "unknown seed")

	# Plant, grow, harvest
	check(gs.interact("farm", plot, "wheat") == "planted" and gs.coins == 488, "plant wheat costs 2")
	check(is_equal_approx(gs.progress("farm", plot), 0.0), "progress starts at 0")
	gs.clock_override = 1030.0
	check(is_equal_approx(gs.progress("farm", plot), 0.5) and gs.seconds_left("farm", plot) == 30, "half grown")
	check(gs.interact("farm", plot, "wheat") == "growing" and gs.inventory.count("wheat") == 0, "cannot harvest early")
	gs.clock_override = 1060.0
	check(gs.progress("farm", plot) >= 1.0, "ripe after 60s")
	check(gs.interact("farm", plot, "wheat") == "harvested" and gs.inventory.count("wheat") == 1, "harvest wheat")
	check(gs.progress("farm", plot) == -1.0, "plot empty after harvest")
	gs.clock_override = 500.0
	gs.interact("farm", plot, "tomato")
	gs.clock_override = 400.0
	check(gs.progress("farm", plot) == 0.0, "clock going backwards never gives negative progress")
	gs.grid("farm").states.erase(plot)
	gs.clock_override = 1060.0

	# Not enough coins for seed
	var saved: int = gs.coins
	gs.coins = 1
	check(gs.interact("farm", plot, "wheat") == "no_coins" and gs.coins == 1, "seed needs coins")
	gs.coins = saved

	# Full barn blocks harvest and keeps the crop
	gs.interact("farm", plot, "wheat")
	gs.clock_override = 1200.0
	var cap: int = gs.inventory.capacity
	gs.inventory.capacity = gs.inventory.total()
	check(gs.interact("farm", plot, "wheat") == "full" and gs.progress("farm", plot) >= 1.0, "full barn keeps ripe crop")
	gs.inventory.capacity = cap
	check(gs.interact("farm", plot, "wheat") == "harvested" and gs.inventory.count("wheat") == 2, "harvest after freeing space")

	# Coop: needs wheat, produces egg
	check(gs.place_object("farm", coop, "farm_coop_01") == "ok" and gs.grid("farm").origin_at(Vector2i(34, 34)) == coop_origin, "place 3x3 coop centred on the tapped cell")
	check(gs.place_object("farm", Vector2i(33, 29), "farm_plot_01") == "occupied", "plot cannot overlap the coop")
	gs.inventory.remove("wheat", 2)
	check(gs.interact("farm", Vector2i(34, 34), "wheat") == "no_feed", "coop needs feed (tapping any of its cells)")
	gs.inventory.add("wheat", 1)
	check(gs.interact("farm", coop_origin, "wheat") == "fed" and gs.inventory.count("wheat") == 0, "feed coop")
	check(gs.interact("farm", coop_origin, "wheat") == "busy", "coop busy")
	gs.clock_override += 119.0
	check(gs.interact("farm", coop_origin, "wheat") == "busy", "coop not ready at 119s")
	gs.clock_override += 1.0
	check(gs.interact("farm", coop_origin, "wheat") == "collected" and gs.inventory.count("egg") == 1, "collect egg")

	# Fence and other objects are not interactive
	check(gs.place_object("farm", plot2, "farm_fence_01") == "ok", "place fence")
	check(gs.interact("farm", plot2, "wheat") == "invalid", "fence not interactive")

	# Selling
	gs.inventory.add("wheat", 3)
	gs.inventory.add("tomato", 2)
	var before: int = gs.coins
	check(gs.sell("egg", 5) == 10 and gs.coins == before + 10 and gs.inventory.count("egg") == 0, "sell egg")
	check(gs.sell("egg", 1) == 0 and gs.sell("bogus", 1) == 0, "cannot sell what you lack")
	check(gs.sell_all() == 3 * 4 + 2 * 14 and gs.inventory.total() == 0, "sell all")

	# Removing a growing plot discards the crop and clears state
	gs.interact("farm", plot, "cabbage")
	check(gs.grid("farm").states.has(plot), "state exists while growing")
	check(gs.store_loses_state("farm", plot) and gs.store_object("farm", plot) == "ok" and not gs.grid("farm").states.has(plot), "storing clears what grew on it")
	check(gs.place_object("farm", plot_c, "farm_plot_01") == "ok" and gs.progress("farm", plot) == -1.0, "re-placed plot is empty")

	# Persistence including offline growth
	gs.autosave = true
	gs.clock_override = 5000.0
	gs.interact("farm", plot, "wheat")
	gs.save_game()
	gs.reset()
	gs.clock_override = 5030.0
	check(gs.load_game() and gs.grid("farm").states.has(plot), "crop state saved")
	check(is_equal_approx(gs.progress("farm", plot), 0.5), "progress continues after reload")
	gs.clock_override = 5100.0
	check(gs.progress("farm", plot) >= 1.0, "grows while the game is closed")
	check(gs.grid("farm").objects.get(coop_origin) == "farm_coop_01", "coop persisted")

	# Old phase-1 saves without "states" still load
	var old := {"version": 1, "coins": 77, "language": "en", "grids": {"farm": {"size": [12, 12], "start": 9, "owned": [[4, 4]], "objects": [[4, 4, "farm_plot_01"]]}}}
	var f := FileAccess.open(gs.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	gs.reset()
	check(gs.load_game() and gs.coins == 77 and gs.progress("farm", Vector2i(4, 4)) == -1.0 and gs.grid("farm").objects.is_empty(), "old save loads (coins kept)")

	# Never soft-lock: with no coins, nothing to sell and nothing growing, the player can still start over
	gs.reset()
	gs.level = 10
	gs.autosave = false
	gs.coins = 0
	check(gs.is_broke(), "broke when nothing can earn money")
	check(gs.place_object("farm", plot_c, "farm_plot_01") == "ok" and gs.coins == 0, "first plot is free when broke")
	check(gs.interact("farm", plot, "tomato") == "no_coins", "only wheat is free")
	check(gs.interact("farm", plot, "wheat") == "planted" and gs.coins == 0, "free wheat when broke")
	check(not gs.is_broke(), "growing crop means not broke")
	gs.coins = 0
	check(gs.place_object("farm", plot2_c, "farm_plot_01") == "no_coins", "second plot is not free")
	gs.clock_override = 99999.0
	gs.interact("farm", plot, "wheat")
	check(gs.inventory.count("wheat") == 1 and not gs.is_broke(), "harvest gives sellable item")
	gs.coins = 3
	check(not gs.is_broke(), "enough coins for a seed is not broke")
	var before_grant: int = gs.coins
	gs.grant_test_coins()
	check(gs.coins == before_grant + gs.TEST_GRANT, "test grant adds coins")
	gs.clock_override = 1000.0

	# Every string the farm uses exists in both languages
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(loc.STRINGS_PATH))
	var names: Array = []
	for crop in Catalog.CROPS:
		names.append(Catalog.CROPS[crop].name)
	for item in Catalog.ITEMS:
		names.append(Catalog.ITEMS[item].name)
	for id in Catalog.PLACEABLES:
		names.append(Catalog.PLACEABLES[id].name)
	for n in names:
		check(parsed.has(n) and str(parsed[n].en) != "" and str(parsed[n].th) != "", "string %s present" % n)

	# World scene: placement mode, tap-to-plant bubble, instant harvest, barn modal and selling
	gs.reset()
	gs.level = 10
	gs.autosave = false
	gs.clock_override = 9000.0
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_zone("farm")
	world.start_placement("farm_plot_01")
	world.set_ghost(plot_c)
	check(world.placement_status() == "ok" and world.hud.placement_bar.visible and not world.hud.placement_ok.disabled, "placement bar enabled for a valid spot")
	world.confirm_placement()
	check(gs.grid("farm").objects.get(plot) == "farm_plot_01", "confirm places the plot")
	check(world.ghost_cell == plot_c + Vector2i(4, 0) and world.placement_status() == "ok", "ghost steps to the next free spot after placing")
	world.set_ghost(plot_c)
	check(world.placement_status() == "occupied" and world.hud.placement_ok.disabled, "the used spot is now blocked")
	world.cancel_placement()
	check(not world.hud.placement_bar.visible, "cancel hides the placement bar")
	world._on_tap(Iso.unit_corner(plot) + Vector2(8, 8))
	check(world.hud.context.visible and world.selected_origin == plot, "tap on an empty plot opens the bubble")
	world._on_crop_chosen("wheat")
	check(gs.grid("farm").states.has(plot) and not world.hud.context.visible, "choosing a crop plants it")
	world._on_tap(Iso.unit_corner(plot) + Vector2(8, 8))
	check(world.hud.context.visible, "tap on a growing plot shows its status")
	world._deselect()
	gs.clock_override = 9061.0
	world._on_tap(Iso.unit_corner(plot) + Vector2(8, 8))
	check(gs.inventory.count("wheat") == 1 and not world.hud.context.visible, "one tap harvests a ripe plot")
	world.hud.open_modal("barn")
	check(world.hud.modal.visible and world.hud.modal_kind == "barn", "barn modal opens")
	var coins_before: int = gs.coins
	check(gs.sell_all() == 4 and gs.coins == coins_before + 4, "barn sells everything")
	check(world.hud.modal_body.get_child_count() >= 2, "barn modal rebuilt after selling")
	var cap_before: int = gs.inventory.capacity
	gs.coins = 1000
	check(gs.barn_upgrade_cost() == 100 and gs.upgrade_barn() == "ok" and gs.inventory.capacity == cap_before + 30 and gs.coins == 900, "barn upgrade")
	check(gs.barn_upgrade_cost() == 200, "barn upgrade cost grows")
	world.hud.close_modal()
	loc.set_language("th")
	world.hud.open_modal("barn")
	loc.set_language("en")
	world.set_zone("restaurant")
	check(not world.hud.modal.visible, "switching zone closes panels")
	await process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: phase 2 farm (plots, growth, offline time, coop, barn, selling, UI taps)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)
