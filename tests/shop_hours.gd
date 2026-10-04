extends SceneTree

# Opening hours: customers only come while the restaurant is open; time keeps running either way.
var failures := 0

func check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# the schedule
	var h := ShopHours.new()
	check(h.open_hour == 9 and h.close_hour == 21, "default hours are 9:00 to 21:00")
	check(not h.scheduled_open(8.9) and h.scheduled_open(9.0) and h.scheduled_open(20.9) and not h.scheduled_open(21.0), "open from 9:00 up to 21:00")
	check(h.scheduled_open(8.9995 + 0.0004) , "a clock float a hair under 9:00 still counts as open")

	# close now: lasts until the schedule next changes
	h.force(false, 10.0)
	check(not h.is_open(12.0) and not h.is_open(20.5), "close now keeps it closed while the schedule still says open")
	h.refresh(21.5)
	check(h.override == "" and not h.is_open(21.5), "the override ends when the schedule closes")
	check(h.is_open(9.5), "next morning it opens by itself")

	# open now: lasts until the schedule next changes
	h.reset()
	h.force(true, 7.0)
	check(h.is_open(8.0), "open now opens it before the opening hour")
	h.refresh(9.5)
	check(h.override == "" and h.is_open(9.5), "at 9:00 the schedule takes over (still open)")
	check(not h.is_open(22.0), "and it closes at 21:00 as scheduled")

	# setting the hours
	h.reset()
	h.set_hours(10, 10, 12.0)
	check(h.open_hour == 10 and h.close_hour == 11, "at least one hour open")
	h.set_hours(23, 23, 12.0)
	check(h.open_hour == 23 and h.close_hour == 24, "latest opening is 23:00, closing is 24:00 at most")
	h.set_hours(-5, 99, 12.0)
	check(h.open_hour == 0 and h.close_hour == 24, "hours are clamped to the day")
	h.reset()
	h.force(false, 10.0)
	h.set_hours(9, 12, 13.0)   # the schedule now says closed at 13:00, unlike when it was forced
	check(h.override == "", "changing the hours so the schedule moves past an override ends it")

	# saving
	h.reset()
	h.set_hours(8, 20, 7.0)
	h.force(true, 7.0)
	var h2 := ShopHours.new()
	h2.load_dict(h.to_dict())
	check(h2.open_hour == 8 and h2.close_hour == 20 and h2.override == "open" and h2.is_open(7.5), "hours and override survive a save")
	var bad := ShopHours.new()
	bad.load_dict({"open": 30, "close": 2, "override": "banana"})
	check(bad.open_hour == 23 and bad.close_hour == 24 and bad.override == "", "a damaged save is clamped")

	# in the game
	var gs = root.get_node("/root/GameState")
	gs.restaurant_active = false
	gs.ask_names = false
	gs.use_sandbox_layouts()
	gs.spawn_obstacles = false
	gs.save_path = "user://test_salvora_hours.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.autosave = false
	gs.reset()
	check(is_equal_approx(gs.day_clock.hour(), 6.0) and not gs.shop_open(), "a new game starts at 6:00 and the restaurant is not open yet")
	gs.level = 10
	gs.coins = 5000
	gs.place_object("restaurant", Vector2i(27, 27), "rest_table_small_01")
	gs.place_object("restaurant", Vector2i(31, 31), "rest_stove_01")
	var r = gs.restaurant
	r.rng.seed = 7
	r.arrival_timer = 0.0
	r.tick(1.0)
	check(r.customers.is_empty(), "no customers arrive while closed")
	var t0: float = gs.day_clock.t
	gs.day_clock.tick(10.0)
	check(gs.day_clock.t > t0, "time keeps running while closed")
	gs.day_clock.t = 3.5 / 24.0   # 9:30
	check(gs.shop_open(), "open at 9:30")
	r.arrival_timer = 0.0
	r.tick(0.01)
	check(r.customers.size() == 1, "a customer arrives while open")
	var inside: int = r.customers[0].id
	gs.force_shop(false)
	check(not gs.shop_open(), "close now closes it")
	var patience_before: float = r.customers[0].patience
	r.arrival_timer = 0.0
	r.tick(1.0)
	check(r.customers.size() == 1 and r.customers[0].id == inside and r.customers[0].patience < patience_before, "the customer inside stays and is served as usual, but no new one arrives")
	gs.force_shop(true)
	check(gs.shop_open(), "open now opens it again")
	gs.set_shop_hours(8, 20)
	check(gs.shop_hours.open_hour == 8 and gs.shop_hours.close_hour == 20, "the player sets the hours")
	check(gs.save_game(), "saves")
	gs.reset()
	check(gs.shop_hours.open_hour == 9, "reset brings the default hours back")
	check(gs.load_game() and gs.shop_hours.open_hour == 8 and gs.shop_hours.close_hour == 20, "the hours come back from the save")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: shop hours (schedule, open/close now, closed = no new customers, saves)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)
