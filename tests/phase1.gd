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
	gs.restaurant_active = false
	gs.ask_names = false
	gs.layout = Island.sandbox()
	gs.spawn_obstacles = false
	gs.save_path = "user://test_salvora.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.reset()
	gs.level = 10

	# Iso grid maths
	for c in [Vector2i(0, 0), Vector2i(3, 5), Vector2i(29, 0), Vector2i(0, 29)]:
		check(Iso.world_to_cell(Iso.cell_to_world(c)) == c, "iso round trip %s" % c)
		check(Iso.world_to_cell(Iso.cell_to_world(c) + Vector2(10, 5)) == c, "iso inside cell %s" % c)
	var corners := Iso.footprint_corners(Vector2i(3, 4), Vector2i(2, 2))
	check(is_equal_approx(corners[1].x - corners[3].x, Iso.footprint_width(Vector2i(2, 2))), "footprint width matches corners")
	check(Iso.footprint_center(Vector2i(3, 4), Vector2i(1, 1)) == Iso.cell_to_world(Vector2i(3, 4)), "1x1 footprint centre is the cell")

	# WorldGrid: land blocks and multi-cell footprints
	var g := WorldGrid.new(Vector2i(12, 12), [Vector2i(0, 0)])
	var two := Vector2i(2, 2)
	check(g.can_place(Vector2i(0, 0), two) and not g.can_place(Vector2i(5, 5), two), "place only on owned land")
	check(g.is_owned(Vector2i(5, 5)) and not g.is_owned(Vector2i(6, 0)), "block edge is 6 cells")
	check(g.can_buy_parcel(Vector2i(1, 0)) and not g.can_buy_parcel(Vector2i(1, 1)), "buy only edge-adjacent blocks")
	check(not g.can_buy_parcel(Vector2i(2, 0)) and not g.can_buy_parcel(Vector2i(0, 0)), "no out-of-bounds or owned blocks")
	check(g.buy_parcel(Vector2i(1, 0)) and g.bought_count() == 1, "buy block")
	check(g.is_owned(Vector2i(11, 5)) and g.is_owned(Vector2i(6, 0)), "whole block owned after one buy")
	check(g.place(Vector2i(5, 0), "x", two) and not g.can_place(Vector2i(6, 0), two), "footprint blocks overlap")
	check(g.origin_at(Vector2i(6, 1)) == Vector2i(5, 0) and g.id_at(Vector2i(6, 1)) == "x", "any covered cell finds the object")
	check(not g.place(Vector2i(11, 0), "y", two), "footprint cannot leave the map")
	check(g.remove_at(Vector2i(6, 1)) == "x" and g.remove_at(Vector2i(5, 0)) == "", "remove frees every cell")
	check(g.place(Vector2i(6, 0), "t", two) and g.place(Vector2i(0, 0), "f", Vector2i.ONE), "cells free again after remove")
	g.states[Vector2i(6, 0)] = {"k": 1}
	var g2 := WorldGrid.new(Vector2i(12, 12))
	check(g2.load_dict(JSON.parse_string(JSON.stringify(g.to_dict()))), "grid loads its own format")
	check(g2.is_owned(Vector2i(8, 3)) and g2.objects.get(Vector2i(6, 0)) == "t" and g2.bought_count() == 1, "grid json round trip")
	check(int(g2.states.get(Vector2i(6, 0), {}).get("k", 0)) == 1 and g2.origin_at(Vector2i(7, 1)) == Vector2i(6, 0), "footprints and state restored")
	var g3 := WorldGrid.new(Vector2i(12, 12), [Vector2i(0, 0)])
	check(not g3.load_dict({"size": [12, 12], "owned": [[1, 1]], "objects": []}) and g3.owned_parcels.size() == 1, "old-format grid rejected, untouched")

	# Inventory
	var inv := Inventory.new(5)
	check(inv.add("egg", 3) == 3 and inv.add("milk", 4) == 2, "inventory capacity cap")
	check(not inv.remove("egg", 9) and inv.remove("egg", 3) and inv.count("egg") == 0, "inventory remove")
	var inv2 := Inventory.new(1)
	inv2.load_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	check(inv2.count("milk") == 2 and inv2.capacity == 5, "inventory round trip")

	# GameState economy (start block is cells 12..17)
	check(gs.coins == 500, "start coins")
	check(gs.grid("restaurant").is_owned(Vector2i(12, 12)) and gs.grid("restaurant").is_owned(Vector2i(17, 17)) and not gs.grid("restaurant").is_owned(Vector2i(18, 12)), "start block")
	check(gs.buy_land("restaurant", Vector2i(0, 0)) == "invalid", "buy far block rejected")
	check(gs.buy_land("restaurant", Vector2i(20, 14)) == "ok" and gs.coins == 350, "buy block costs 150")
	check(gs.grid("restaurant").is_owned(Vector2i(18, 12)) and gs.grid("restaurant").is_owned(Vector2i(23, 17)), "tapping any cell buys the whole block")
	check(gs.land_cost("restaurant") == 250, "land cost grows with every block bought")
	check(gs.place_object("restaurant", Vector2i(13, 13), "rest_table_small_01") == "ok" and gs.coins == 320, "place table")
	check(gs.place_object("restaurant", Vector2i(14, 14), "rest_stove_01") == "occupied", "overlap rejected")
	check(gs.place_object("restaurant", Vector2i(0, 0), "rest_stove_01") == "locked", "locked")
	check(gs.place_object("restaurant", Vector2i(17, 13), "rest_stove_01") == "ok" and gs.coins == 240, "footprint may span two owned blocks")
	check(gs.place_object("restaurant", Vector2i(5, 5), "not_an_item") == "invalid", "unknown item")
	check(gs.remove_object("restaurant", Vector2i(14, 14)) == "ok" and gs.coins == 240 + 15, "remove from any covered cell refunds half")
	gs.remove_object("restaurant", Vector2i(18, 14))
	gs.coins = 5
	check(gs.place_object("restaurant", Vector2i(13, 13), "rest_stove_01") == "no_coins" and gs.coins == 5, "no coins")
	gs.coins = 321
	gs.set_language("th")
	gs.place_object("restaurant", Vector2i(13, 13), "rest_table_small_01")
	var saved_coins: int = gs.coins
	gs.reset()
	check(gs.load_game(), "load succeeds")
	check(gs.coins == saved_coins and gs.language == "th", "coins and language persisted")
	check(gs.grid("restaurant").objects.get(Vector2i(13, 13)) == "rest_table_small_01", "objects persisted")
	check(gs.grid("restaurant").is_owned(Vector2i(18, 12)), "bought block persisted")

	# A save from before land blocks keeps coins but starts a fresh map
	var legacy := {"version": 1, "coins": 99, "language": "en", "grids": {"restaurant": {"size": [12, 12], "start": 9, "owned": [[4, 4]], "objects": [[4, 4, "rest_table_small_01"]]}}}
	var lf := FileAccess.open(gs.save_path, FileAccess.WRITE)
	lf.store_string(JSON.stringify(legacy))
	lf.close()
	gs.reset()
	check(gs.load_game() and gs.coins == 99 and gs.grid("restaurant").objects.is_empty(), "legacy save: coins kept, map reset")

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
	# Controls under a CanvasLayer must resolve to the bundled font (web has no system fonts).
	var probe_layer := CanvasLayer.new()
	var probe := Label.new()
	probe_layer.add_child(probe)
	root.add_child(probe_layer)
	var font: Font = probe.get_theme_default_font()
	check(font.get_font_name() == "Noto Sans Thai", "UI font is the bundled Noto Sans Thai")
	check(font.has_char(0x0E01) and font.has_char(0x0E48) and font.has_char(65), "UI font covers Thai and Latin")
	probe_layer.queue_free()

	# Assets: missing art falls back to null (placeholder), no crash
	check(assets.get_tex("definitely_not_a_real_asset") == null, "missing asset returns null")
	for id in Catalog.PLACEABLES:
		check(Catalog.PLACEABLES[id].area in ["restaurant", "farm"], "placeable area valid %s" % id)

	# World scene: HUD, confirmation before buying, placement mode, selecting and selling
	gs.reset()
	gs.level = 10
	gs.autosave = false
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.camera.position = Iso.cell_to_world(gs.start_cell())
	world.camera.zoom = Vector2.ONE
	check(world.hud.level_label.text.contains("10") and world.hud.coins_label.text == "500", "HUD shows level and coins")
	world._on_tap(Iso.cell_to_world(Vector2i(20, 14)))
	check(world.hud.modal.visible and world.hud.modal_kind == "confirm" and gs.coins == 500, "tapping a block asks before buying")
	world.hud.close_modal()
	check(not gs.grid("restaurant").is_owned(Vector2i(20, 14)), "cancel keeps the land unbought")
	world._on_tap(Iso.cell_to_world(Vector2i(20, 14)))
	world.hud.confirm_yes.call()
	check(gs.grid("restaurant").is_owned(Vector2i(20, 14)) and gs.coins == 350, "confirming buys the whole block")
	check(world.hud.coins_label.text == "350", "HUD updates after buying")
	world.start_placement("rest_table_small_01")
	world.set_ghost(Vector2i(14, 14))
	check(world.placement_status() == "ok", "ghost on free owned land is valid")
	world.set_ghost(Vector2i(3, 3))
	check(world.placement_status() == "locked" and world.hud.placement_ok.disabled, "ghost on unowned land is invalid")
	world.set_ghost(Vector2i(14, 14))
	world.confirm_placement()
	check(gs.grid("restaurant").objects.has(Vector2i(14, 14)) and gs.coins == 320, "confirm places the table")
	world.cancel_placement()
	world._on_tap(Iso.cell_to_world(Vector2i(15, 15)))
	check(world.selected_origin == Vector2i(14, 14) and world.hud.context.visible, "tapping any covered cell selects the table")
	world._on_move_requested()
	check(world.moving_origin == Vector2i(14, 14) and world.placing_id == "rest_table_small_01" and not world.hud.context.visible, "move starts placement mode")
	world.set_ghost(Vector2i(16, 16))
	world.confirm_placement()
	check(gs.grid("restaurant").objects.has(Vector2i(16, 16)) and not gs.grid("restaurant").objects.has(Vector2i(14, 14)) and gs.coins == 320, "moving is free and relocates the object")
	check(world.placing_id == "", "move ends placement mode")
	world._on_tap(Iso.cell_to_world(Vector2i(16, 16)))
	world._on_sell_requested()
	check(world.hud.modal.visible and world.hud.modal_kind == "confirm", "selling asks for confirmation")
	world.hud.confirm_yes.call()
	check(gs.grid("restaurant").objects.is_empty() and gs.coins == 335, "confirmed sale removes it and refunds half")
	world.hud.open_modal("shop")
	check(world.hud.modal_kind == "shop" and world.hud.modal_body.get_child_count() >= 2, "shop lists items")
	world.hud.close_modal()
	check(world.zone == Catalog.ISLAND, "one island, no zone switch")
	world.hud.open_modal("settings")
	check(world.hud.modal_kind == "settings", "menu opens")
	world.hud.close_modal()
	world.queue_redraw()
	await process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: phase 1 core (grid, inventory, economy, save, i18n, world scene)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)
