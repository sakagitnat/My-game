extends SceneTree

# A new game is ready to play (a furnished shop, a garden, wheat in the barn, the shop open); the goals walk the player
# through harvesting, cooking and serving, pay out when claimed and survive a save; sleeping skips the closed hours.

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
	gs.save_path = "user://test_salvora_goals.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.load_default_layouts()
	gs.clock_override = 10000.0
	gs.new_game()

	# the starter kit
	var g = gs.grid("restaurant")
	var ids: Array = g.objects.values()
	check(ids.count("rest_stove_01") == 1, "a stove to start with")
	check(ids.count("rest_table_small_01") == 2, "two tables to start with")
	check(ids.count("farm_plot_01") == 4, "four garden plots: %d" % ids.count("farm_plot_01"))
	check(g.states.size() == 2, "two plots have wheat growing")
	check(gs.restaurant.has_service(), "the restaurant can serve at once")
	check(gs.inventory.count("wheat") == 4, "wheat in the barn for the first dish")
	check(gs.shop_open(), "the first day starts with the shop open: %s" % gs.day_clock.hour())
	check(gs.coins == gs.START_COINS and gs.xp == 0, "the kit is free and gives no XP")

	# goal 1: harvest 2
	var info: Dictionary = gs.goal_info()
	check(info.id == "harvest" and info.progress == 0 and not info.done, "the first goal is to harvest")
	check(gs.claim_goal() == "not_done", "an unfinished goal cannot be claimed")
	gs.clock_override += 60.0
	for origin in g.states.keys():
		check(gs.interact("restaurant", origin, "") == "harvested", "the starter wheat ripens soon")
	info = gs.goal_info()
	check(info.done and info.progress == 2, "two harvests finish the goal")
	var coins_before: int = gs.coins
	check(gs.claim_goal() == "ok" and gs.coins == coins_before + info.coins, "claiming pays the reward")
	check(gs.goal_info().id == "cook", "then the goal is to cook")

	# goal 2: cook, goal 3: serve 3 (counted from when it starts)
	check(gs.cook_dish("wheat_porridge") == "ok", "the barn wheat cooks a porridge")
	check(gs.goal_info().done, "cooking finishes the cook goal")
	gs.claim_goal()
	gs.stats["served"] = 0
	gs.bump("served", 2)
	check(gs.goal_info().progress == 2 and not gs.goal_info().done, "serving counts: 2 of 3")
	gs.restaurant._spawn()
	var c: Dictionary = gs.restaurant.customers[0]
	gs.restaurant.counter.append(c.dish)
	check(gs.serve_customer(c.id).result == "ok" and gs.goal_info().done, "the third serve finishes it")
	gs.claim_goal()
	check(gs.goal_info().id == "plant" and gs.goal_info().progress == 0, "a stat goal counts from when it starts")

	# a "count" goal measures the map; a "level" goal the level
	var tables_goal: Dictionary = Goals.goal_at(4)
	check(Goals.measure(tables_goal, gs, 0) == 2, "the tables goal sees the two tables")
	check(Goals.measure(Goals.goal_at(5), gs, 0) == gs.level, "the level goal reads the level")
	var endless: Dictionary = Goals.goal_at(Goals.LIST.size() + 2)
	check(endless.stat == "served" and endless.n > Goals.goal_at(Goals.LIST.size()).n, "endless goals grow")

	# saved and loaded
	gs.save_game()
	var idx: int = gs.goals.index
	var planted: int = gs.stats.get("planted", 0)
	gs.reset()
	check(gs.goals.index == 0 and gs.stats.is_empty(), "reset clears the goals")
	check(gs.load_game() and gs.goals.index == idx and gs.stats.get("planted", 0) == planted, "goals and stats come back from the save")

	# sleeping through the night
	gs.day_clock.t = (22.0 - DayClock.START_HOUR) / 24.0
	check(not gs.shop_open(), "closed at 22:00")
	var days: int = gs.day_clock.days
	check(gs.sleep_until_open() == "ok" and gs.shop_open(), "sleeping wakes at opening time")
	check(gs.day_clock.days == days + 1 and is_equal_approx(gs.day_clock.hour(), float(gs.shop_hours.open_hour)), "on the next day at the opening hour")
	check(gs.sleep_until_open() == "open", "no sleeping while open")
	gs.day_clock.t = (6.5 - DayClock.START_HOUR) / 24.0
	days = gs.day_clock.days
	gs.sleep_until_open()
	check(gs.day_clock.days == days and gs.shop_open(), "early morning sleeps to the same day's opening")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: goals (starter kit, goal chain, rewards, save, sleep)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)
