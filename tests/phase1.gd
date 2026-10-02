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
	gs.save_path = "user://test_salvora.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.reset()

	# Iso grid maths
	for c in [Vector2i(0, 0), Vector2i(3, 5), Vector2i(11, 0), Vector2i(0, 11)]:
		check(Iso.world_to_cell(Iso.cell_to_world(c)) == c, "iso round trip %s" % c)
		check(Iso.world_to_cell(Iso.cell_to_world(c) + Vector2(20, 10)) == c, "iso inside cell %s" % c)

	# WorldGrid rules
	var g := WorldGrid.new(Vector2i(5, 5), [Vector2i(2, 2)])
	check(g.can_place(Vector2i(2, 2)) and not g.can_place(Vector2i(1, 2)), "place only on owned")
	check(g.can_buy(Vector2i(2, 3)) and not g.can_buy(Vector2i(0, 0)), "buy only adjacent")
	check(not g.can_buy(Vector2i(5, 2)), "no buying out of bounds")
	check(g.buy(Vector2i(2, 3)) and g.bought_count() == 1, "buy cell")
	check(g.place(Vector2i(2, 2), "x") and not g.place(Vector2i(2, 2), "y"), "no double place")
	check(g.remove(Vector2i(2, 2)) == "x" and g.remove(Vector2i(2, 2)) == "", "remove")
	g.place(Vector2i(2, 3), "t")
	var g2 := WorldGrid.new(Vector2i(5, 5))
	g2.load_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.is_owned(Vector2i(2, 3)) and g2.objects.get(Vector2i(2, 3)) == "t" and g2.bought_count() == 1, "grid json round trip")

	# Inventory
	var inv := Inventory.new(5)
	check(inv.add("egg", 3) == 3 and inv.add("milk", 4) == 2, "inventory capacity cap")
	check(not inv.remove("egg", 9) and inv.remove("egg", 3) and inv.count("egg") == 0, "inventory remove")
	var inv2 := Inventory.new(1)
	inv2.load_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	check(inv2.count("milk") == 2 and inv2.capacity == 5, "inventory round trip")

	# GameState economy
	check(gs.coins == 500, "start coins")
	check(gs.buy_land("restaurant", Vector2i(0, 0)) == "invalid", "buy far cell rejected")
	check(gs.buy_land("restaurant", Vector2i(3, 4)) == "ok" and gs.coins == 450, "buy land costs 50")
	check(gs.land_cost("restaurant") == 75 and gs.land_cost("farm") == 50, "land cost scales per zone")
	check(gs.place_object("restaurant", Vector2i(4, 4), "rest_table_small_01") == "ok" and gs.coins == 420, "place table")
	check(gs.place_object("restaurant", Vector2i(4, 4), "rest_stove_01") == "occupied", "occupied")
	check(gs.place_object("restaurant", Vector2i(0, 0), "rest_stove_01") == "locked", "locked")
	check(gs.place_object("restaurant", Vector2i(5, 5), "farm_fence_01") == "invalid", "wrong zone item")
	check(gs.remove_object("restaurant", Vector2i(4, 4)) == "ok" and gs.coins == 435, "remove refunds half")
	gs.coins = 5
	check(gs.place_object("restaurant", Vector2i(4, 4), "rest_stove_01") == "no_coins" and gs.coins == 5, "no coins")
	gs.coins = 321
	gs.set_language("th")
	gs.place_object("restaurant", Vector2i(5, 5), "rest_table_small_01")
	var saved_coins: int = gs.coins
	gs.reset()
	check(gs.load_game(), "load succeeds")
	check(gs.coins == saved_coins and gs.language == "th", "coins and language persisted")
	check(gs.grid("restaurant").objects.get(Vector2i(5, 5)) == "rest_table_small_01", "objects persisted")
	check(gs.grid("restaurant").is_owned(Vector2i(3, 4)), "bought land persisted")

	# Corrupt / foreign save files fall back safely
	var f := FileAccess.open(gs.save_path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	check(SaveStore.read(gs.save_path).is_empty(), "corrupt save ignored")
	f = FileAccess.open(gs.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 999, "coins": 1}))
	f.close()
	check(SaveStore.read(gs.save_path).is_empty(), "unknown save version ignored")

	# Localisation: every key translated in every language
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(loc.STRINGS_PATH))
	check(parsed is Dictionary and parsed.size() > 10, "strings.json parses")
	for key in parsed:
		for lang in loc.LANGS:
			check(str(parsed[key].get(lang, "")) != "", "string %s has %s" % [key, lang])
	loc.set_language("th")
	check(loc.t("ZONE_FARM") == "ฟาร์ม", "Thai translation active")
	loc.set_language("en")
	check(loc.t("ZONE_FARM") == "Farm", "English translation active")
	check(root.theme != null and root.theme.default_font != null, "UI font applied")
	var fonts_ok: bool = ThemeDB.fallback_font.has_char("ก".unicode_at(0)) or ThemeDB.fallback_font.fallbacks.size() > 0
	check(fonts_ok, "Thai glyph fallback configured")

	# Assets: missing art falls back to null (placeholder), no crash
	check(assets.get_tex("definitely_not_a_real_asset") == null, "missing asset returns null")
	for id in Catalog.PLACEABLES:
		check(Catalog.PLACEABLES[id].zone in Catalog.ZONES, "placeable zone valid %s" % id)

	# World scene: build, tap through the real input path
	gs.reset()
	gs.autosave = false
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.camera.position = Iso.cell_to_world(Vector2i(3, 4))
	world.camera.zoom = Vector2.ONE
	world.tool = "buy"
	world._on_tap(Iso.cell_to_world(Vector2i(3, 4)))
	check(gs.grid("restaurant").is_owned(Vector2i(3, 4)) and gs.coins == 450, "tap buys land")
	world.tool = "rest_table_small_01"
	world._on_tap(Iso.cell_to_world(Vector2i(4, 4)))
	check(gs.grid("restaurant").objects.has(Vector2i(4, 4)), "tap places table")
	world.tool = "remove"
	world._on_tap(Iso.cell_to_world(Vector2i(4, 4)))
	check(not gs.grid("restaurant").objects.has(Vector2i(4, 4)), "tap removes table")
	world.set_zone("farm")
	check(world.tool_buttons.has("farm_fence_01") and not world.tool_buttons.has("rest_table_small_01"), "farm palette")
	world.queue_redraw()
	await process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: phase 1 core (grid, inventory, economy, save, i18n, world scene)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)
