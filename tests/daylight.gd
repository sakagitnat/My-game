extends SceneTree

# Time of day: the clock, the tint and shadow curves, saving, the test button and the renderer following the clock.
var failures := 0

func check(cond: bool, label: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func close_to(a: Color, b: Color, eps: float = 0.01) -> bool:
	return absf(a.r - b.r) < eps and absf(a.g - b.g) < eps and absf(a.b - b.b) < eps

func run() -> void:
	var c := DayClock.new()
	check(c.phase() == "morning" and c.t == 0.0 and c.days == 0 and is_equal_approx(c.hour(), 6.0), "a new day begins with the morning at 6:00")
	c.tick(DayClock.DAY_SECONDS / 2.0)
	check(c.phase() == "evening" and is_equal_approx(c.hour(), 18.0), "half a day later it is 18:00, evening")
	c.tick(DayClock.DAY_SECONDS / 4.0)
	check(c.phase() == "night" and is_equal_approx(c.hour(), 0.0), "three quarters through it is midnight, night")
	c.tick(DayClock.DAY_SECONDS / 2.0)
	check(c.days == 1 and c.phase() == "day" and is_equal_approx(c.t, 0.25), "past the end the next day starts and the days are counted")
	c.reset()
	var seen := []
	for i in range(4):
		seen.append(c.phase())
		c.skip_to_next_phase()
	check(seen == ["morning", "day", "evening", "night"] and c.phase() == "morning" and c.days == 1, "skipping walks through the four phases and into the next day")

	# Phase lengths: 1/6, 1/3, 1/6, 1/3 of the day
	var secs := {}
	var step := 1.0
	c.reset()
	for i in range(int(DayClock.DAY_SECONDS / step)):
		secs[c.phase()] = float(secs.get(c.phase(), 0.0)) + step
		c.tick(step)
	check(absf(float(secs.morning) - 120.0) < 2.0 and absf(float(secs.day) - 240.0) < 2.0 and absf(float(secs.evening) - 120.0) < 2.0 and absf(float(secs.night) - 240.0) < 2.0, "morning 2, day 4, evening 2, night 4 minutes of a 12 minute day")

	# Tint: white at noon, orange in the evening, blue at night, and no jump anywhere (also across midnight and the new morning)
	c.t = 1.0 / 3.0
	check(close_to(c.tint(), Color.WHITE), "noon is not tinted")
	c.t = 7.0 / 12.0
	check(close_to(c.tint(), Color(1.0, 0.74, 0.58)) and c.tint().r > c.tint().b, "the middle of the evening is orange")
	c.t = 5.0 / 6.0
	check(close_to(c.tint(), Color(0.36, 0.42, 0.68)) and c.tint().b > c.tint().r, "the middle of the night is deep blue")
	var worst := 0.0
	var prev := Color.WHITE
	for i in range(2001):
		c.t = float(i) / 2000.0 * 0.99999
		var col := c.tint()
		if i > 0:
			worst = maxf(worst, maxf(absf(col.r - prev.r), maxf(absf(col.g - prev.g), absf(col.b - prev.b))))
		prev = col
	check(worst < 0.02, "the tint changes smoothly all day (largest step %.4f)" % worst)
	c.t = 0.0
	var start := c.tint()
	c.t = 0.99999
	check(close_to(start, c.tint(), 0.02), "the end of the night fades into the start of the morning")

	# Shadows: right in the morning, left in the evening, short at noon, faint at night
	c.t = 0.0
	var dawn := c.sun()
	c.t = 1.0 / 3.0
	var noon := c.sun()
	c.t = 0.6
	var dusk := c.sun()
	c.t = 5.0 / 6.0
	var night := c.sun()
	check(float(dawn.dir) > 0.9 and float(dusk.dir) < -0.5 and absf(float(noon.dir)) < 0.15, "shadows lean right at dawn, left at dusk, straight at noon")
	check(float(noon.length) < float(dawn.length) and float(noon.alpha) > float(dawn.alpha) and float(night.alpha) < float(noon.alpha) * 0.5, "short and darker at noon, long and soft at dawn, faint at night")
	var gap := 0.0
	var last: Dictionary = {}
	for i in range(2001):
		c.t = float(i) / 2000.0 * 0.99999
		var s := c.sun()
		if not last.is_empty():
			gap = maxf(gap, maxf(absf(float(s.dir) - float(last.dir)), absf(float(s.alpha) - float(last.alpha))))
		last = s
	check(gap < 0.05, "shadows move smoothly all day (largest step %.4f)" % gap)

	# Saving and the game
	var gs = root.get_node("/root/GameState")
	gs.restaurant_active = false
	gs.ask_names = false
	gs.use_sandbox_layouts()
	gs.spawn_obstacles = false
	gs.save_path = "user://test_salvora_daylight.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.autosave = false
	gs.reset()
	check(gs.day_clock.t == 0.0 and gs.day_clock.days == 0, "a new game starts in the morning")
	gs.day_clock.t = 0.62
	gs.day_clock.days = 3
	gs.autosave = true
	gs.save_game()
	gs.reset()
	check(gs.day_clock.t == 0.0, "reset sets the clock back")
	check(gs.load_game() and is_equal_approx(gs.day_clock.t, 0.62) and gs.day_clock.days == 3, "the time of day is saved")
	gs.autosave = false
	var before: float = gs.day_clock.t
	gs._process(36.0)
	check(is_equal_approx(gs.day_clock.t, before + 36.0 / DayClock.DAY_SECONDS), "the game clock advances with game time")

	# On screen
	gs.reset()
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.camera.position = Iso.cell_to_world(gs.start_cell())
	gs.day_clock.t = 5.0 / 6.0
	world.renderer._process(0.016)
	var tint: Color = world.renderer.daylight.get_shader_parameter("tint")
	check(close_to(tint, Color(0.36, 0.42, 0.68)), "the screen is tinted blue at night")
	world.view.edit_mode = true
	world.renderer._process(0.016)
	check(close_to(world.renderer.daylight.get_shader_parameter("tint"), Color.WHITE), "the map editor shows the map untinted")
	world.view.edit_mode = false
	world.hud.open_modal("settings")
	var skip_btn: Button
	for b in world.hud.modal_body.find_children("*", "Button", true, false):
		if b.text.begins_with("Test: next time"):
			skip_btn = b
	check(skip_btn != null, "the menu has a test button to skip the time of day")
	var phase_before: String = gs.day_clock.phase()
	skip_btn.pressed.emit()
	check(gs.day_clock.phase() != phase_before and gs.day_clock.phase() == "morning" and gs.day_clock.days == 1, "pressing it jumps to the next phase")
	world.renderer._sun_timer = 2.0
	world.renderer._process(0.016)
	world.queue_redraw()
	await process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: daylight (clock, tint, shadows, saving, test button, renderer)")
	else:
		print("%d check(s) failed" % failures)
	quit(1 if failures > 0 else 0)
