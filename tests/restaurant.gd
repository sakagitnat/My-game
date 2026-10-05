extends SceneTree

var failures := 0
var events: Array = []

func check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func tick_until_customer(r) -> void:
	r.arrival_timer = 0.0
	r.tick(0.01)

func run() -> void:
	var gs = root.get_node("/root/GameState")
	var loc = root.get_node("/root/Loc")
	loc.set_language("en")
	gs.restaurant_active = false
	gs.ask_names = false
	gs.use_sandbox_layouts()
	gs.spawn_obstacles = false
	gs.save_path = "user://test_salvora6.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.autosave = false
	gs.reset()
	gs.level = 10
	gs.coins = 5000
	gs.clock_override = 1000.0
	var r = gs.restaurant
	r.rng.seed = 424242
	r.customer_arrived.connect(func(id: int) -> void: events.append("arrived"))
	r.customer_left.connect(func(id: int) -> void: events.append("left"))
	r.dish_ready.connect(func(d: String) -> void: events.append("ready:" + d))
	r.served.connect(func(id: int, price: int, tip: int) -> void: events.append("served:%d" % (price + tip)))

	# Opening the restaurant needs a table and a stove
	check(not r.has_service() and r.seats().is_empty(), "empty restaurant is closed")
	gs.place_object("restaurant", Vector2i(27, 27), "rest_table_small_01")
	check(r.tables() == [Vector2i(26, 26)] and r.seats().size() == 2, "a table gives two seats")
	check(r.seats()[0].cell == Vector2i(24, 26) and r.seats()[1].cell == Vector2i(30, 28), "seat cells are on opposite sides of the table")
	check(not r.has_service(), "a table alone does not open the restaurant")
	r.arrival_timer = 0.0
	r.tick(5.0)
	check(r.customers.is_empty(), "no customers without a stove")
	gs.place_object("restaurant", Vector2i(31, 31), "rest_stove_01")
	check(r.has_service() and r.stoves() == [Vector2i(30, 31)], "table + stove opens the restaurant")

	# Recipes follow the level
	gs.level = 1
	check(r.available_recipes() == ["wheat_porridge"], "level 1 only knows porridge")
	gs.level = 3
	check(r.available_recipes().size() == 4, "level 3 knows every dish")
	gs.level = 1
	for i in range(20):
		check(r._pick_dish() == "wheat_porridge", "level 1 customers only order porridge")
		break
	gs.level = 10

	# Arrivals fill seats, never exceed them
	tick_until_customer(r)
	check(r.customers.size() == 1 and events.has("arrived"), "a customer arrives")
	var c0: Dictionary = r.customers[0]
	check(r.seats().any(func(s: Dictionary) -> bool: return s.cell == c0.seat_cell) and Catalog.RECIPES.has(c0.dish) and c0.patience == Catalog.RESTAURANT.patience, "customer sits at a seat and orders a real dish")
	tick_until_customer(r)
	tick_until_customer(r)
	check(r.customers.size() == 2, "customers never exceed the seats")
	check(r.customers[0].index != r.customers[1].index, "two customers take different seats")
	var interval0: float = r._arrival_interval()
	r.reputation = 50
	var interval50: float = r._arrival_interval()
	check(interval0 >= 14.0 and interval0 <= 26.0 and interval50 >= 7.0 and interval50 <= 13.0, "reputation brings customers faster")
	r.reputation = 0

	# Cooking
	r.customers[0].dish = "omelet"
	r.customers[1].dish = "wheat_porridge"
	r.arrival_timer = 99999.0
	check(r.can_cook("omelet") == "no_ingredients" and r.missing("omelet") == {"egg": 2}, "cooking needs ingredients")
	gs.inventory.add("egg", 3)
	gs.level = 1
	check(r.can_cook("cabbage_salad") == "level", "a dish above your level cannot be cooked")
	gs.level = 10
	check(r.can_cook("omelet") == "ok", "ingredients in the barn allow cooking")
	check(gs.cook_dish("omelet") == "ok" and gs.inventory.count("egg") == 1, "cooking takes the ingredients")
	check(r.is_cooking("omelet") and gs.grid("restaurant").states.has(Vector2i(30, 31)), "the dish is on the stove")
	check(gs.progress("restaurant", Vector2i(30, 31)) == 0.0 and gs.seconds_left("restaurant", Vector2i(30, 31)) == 20, "stove progress and timer")
	gs.inventory.add("wheat", 4)
	check(r.can_cook("wheat_porridge") == "busy", "one stove cooks one dish at a time")
	gs.clock_override = 1010.0
	check(is_equal_approx(gs.progress("restaurant", Vector2i(30, 31)), 0.5), "stove progress is half way")
	check(not r.tick(0.1) and r.counter.is_empty(), "nothing at the counter before it is done")
	gs.clock_override = 1020.0
	check(r.tick(0.1) and r.counter == ["omelet"] and events.has("ready:omelet"), "finished dish goes to the counter")
	check(not gs.grid("restaurant").states.has(Vector2i(30, 31)) and not r.is_cooking("omelet"), "the stove is free again")

	# Serving
	var coins_before: int = gs.coins
	var xp_before: int = gs.xp
	var id_porridge: int = r.customers[1].id
	check(r.serve(id_porridge).result == "no_dish" and r.customers.size() == 2, "cannot serve a dish that is not ready")
	check(r.serve(9999).result == "invalid", "unknown customer")
	var id_omelet: int = r.customers[0].id
	var res: Dictionary = gs.serve_customer(id_omelet)
	check(res.result == "ok" and res.price == 40 and res.tip == 10, "served: price 40 plus a 10 tip for a fresh customer")
	check(gs.coins == coins_before + 50 and gs.xp == xp_before + 4 and r.reputation == 1, "serving pays, gives XP and reputation")
	check(r.counter.is_empty() and r.customers.size() == 1 and events.has("served:50"), "the customer and the dish are gone")
	r.customers[0].patience = r.customers[0].max_patience * 0.5
	gs.cook_dish("wheat_porridge")
	gs.clock_override = 1040.0
	r.tick(0.1)
	var res2: Dictionary = gs.serve_customer(r.customers[0].id)
	check(res2.result == "ok" and res2.price == 14 and res2.tip == 2, "a patient-less customer tips less")

	# Counter capacity
	r.counter = ["omelet", "omelet", "omelet", "omelet", "omelet", "omelet"]
	check(r.can_cook("wheat_porridge") == "counter_full", "a full counter stops cooking")
	r.counter.clear()

	# Impatient customers leave and cost reputation
	r.customers.clear()
	tick_until_customer(r)
	r.arrival_timer = 99999.0
	r.reputation = 3
	events.clear()
	r.tick(float(Catalog.RESTAURANT.patience) + 1.0)
	check(r.customers.is_empty() and r.reputation == 2 and events == ["left"], "a customer who waits too long leaves and costs reputation")
	r.reputation = 0
	r.customers.clear()
	tick_until_customer(r)
	r.arrival_timer = 99999.0
	r.tick(float(Catalog.RESTAURANT.patience) + 1.0)
	check(r.reputation == 0, "reputation never goes below zero")

	# Selling or moving the table sends its customers home without penalty
	r.customers.clear()
	r.reputation = 4
	tick_until_customer(r)
	r.arrival_timer = 99999.0
	events.clear()
	gs.store_object("restaurant", Vector2i(27, 27))
	r.tick(0.1)
	check(r.customers.is_empty() and r.reputation == 4 and events == ["left"], "no table: customers leave, reputation unchanged")
	check(not r.has_service(), "without a table the restaurant closes")
	gs.place_object("restaurant", Vector2i(27, 27), "rest_table_small_01")

	# Save, load and offline cooking
	gs.inventory.add("egg", 2)
	r.counter = ["tomato_soup"]
	r.reputation = 7
	gs.clock_override = 2000.0
	gs.cook_dish("omelet")
	gs.autosave = true
	gs.save_game()
	var saved_customers: int = r.customers.size()
	gs.reset()
	check(r.counter.is_empty() and r.reputation == 0, "reset clears the restaurant")
	gs.clock_override = 2100.0
	check(gs.load_game() and r.counter == ["tomato_soup"] and r.reputation == 7, "counter and reputation persist")
	check(gs.grid("restaurant").states.has(Vector2i(30, 31)), "a dish on the stove persists")
	check(r.customers.is_empty() and saved_customers >= 0, "customers are not saved")
	r.arrival_timer = 99999.0
	r.tick(0.1)
	check(r.counter.has("omelet") and r.counter.size() == 2, "a dish finished while the game was closed reaches the counter")
	gs.autosave = false

	# Save without a restaurant section (older saves)
	var f := FileAccess.open(gs.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "coins": 12}))
	f.close()
	gs.reset()
	check(gs.load_game() and r.counter.is_empty() and r.reputation == 0, "older saves load with an empty restaurant")

	# World + HUD panel
	gs.reset()
	gs.level = 10
	gs.coins = 5000
	gs.autosave = false
	gs.clock_override = 3000.0
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var hud = world.hud
	check(hud.rest_panel.visible, "the restaurant panel shows in the restaurant")
	check(hud.rest_body.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == loc.t("REST_NEEDS_SETUP")), "panel explains how to open the restaurant")
	gs.place_object("restaurant", Vector2i(27, 27), "rest_table_small_01")
	gs.place_object("restaurant", Vector2i(31, 31), "rest_stove_01")
	tick_until_customer(r)
	r.arrival_timer = 99999.0
	r.customers[0].dish = "omelet"
	hud._refresh_restaurant(true)
	var buttons: Array = hud.rest_body.find_children("*", "Button", true, false)
	check(buttons.size() == 1 and buttons[0].disabled and buttons[0].text.begins_with("Need"), "no eggs: the button says what is missing")
	gs.inventory.add("egg", 2)
	hud._refresh_restaurant(false)
	buttons = hud.rest_body.find_children("*", "Button", true, false)
	check(buttons.size() == 1 and not buttons[0].disabled and buttons[0].text == loc.t("BTN_COOK"), "with eggs the button offers to cook")
	buttons[0].pressed.emit()
	check(r.is_cooking("omelet") and gs.inventory.count("egg") == 0, "pressing Cook starts the dish")
	hud._refresh_restaurant(true)
	buttons = hud.rest_body.find_children("*", "Button", true, false)
	check(buttons[0].disabled and buttons[0].text == loc.t("COOK_COOKING"), "while cooking the button says so")
	world._on_tap(Iso.cell_to_world(Vector2i(15, 15)))
	check(world.hud.context.visible and world.hud.context_body.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text.contains(loc.t("DISH_OMELET"))), "tapping a cooking stove shows the dish and time left")
	world._deselect()
	gs.clock_override = 3020.0
	r.tick(0.1)
	hud._refresh_restaurant(false)
	buttons = hud.rest_body.find_children("*", "Button", true, false)
	check(buttons[0].text == loc.t("BTN_SERVE") and not buttons[0].disabled, "when the dish is ready the button serves it")
	var coins_pre: int = gs.coins
	buttons[0].pressed.emit()
	check(gs.coins > coins_pre and r.customers.is_empty() and hud.message_key == "MSG_SERVED", "pressing Serve pays the player")

	# The renderer's view mirrors customers and the counter
	tick_until_customer(r)
	r.arrival_timer = 99999.0
	r.counter = ["omelet"]
	world._sync_view()
	check(world.view.customers.size() == 1 and world.view.customers[0].has("seat_cell") and world.view.customers[0].patience_frac > 0.9 and world.view.counter == ["omelet"], "ViewState carries customers and the counter")
	world.set_zone("farm")
	check(not hud.rest_panel.visible, "the panel hides on the farm")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: restaurant (seats, customers, cooking, serving, reputation, saves, panel, view)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)
