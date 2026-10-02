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
	gs.save_path = "user://test_salvora_names.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	gs.autosave = false
	gs.spawn_obstacles = false
	gs.restaurant_active = false
	gs.ask_names = true
	gs.reset()

	check(not gs.has_names(), "a new game has no names")
	check(gs.set_names("  ", "Cafe") == "empty" and not gs.has_names(), "blank names are refused")
	check(gs.set_names("  Mali  ", "Sea Breeze Kitchen Extra Long") == "ok", "names are accepted")
	check(gs.player_name == "Mali" and gs.restaurant_name.length() == gs.NAME_MAX, "names are trimmed and limited")

	gs.autosave = true
	gs.save_game()
	gs.reset()
	check(not gs.has_names(), "reset clears the names")
	check(gs.load_game() and gs.player_name == "Mali" and gs.restaurant_name.length() == gs.NAME_MAX, "names persist in saves")
	var f := FileAccess.open(gs.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "coins": 5}))
	f.close()
	gs.reset()
	check(gs.load_game() and not gs.has_names(), "a save from before names loads and asks again")
	gs.autosave = false

	# The naming screen appears on its own and cannot be skipped
	gs.reset()
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var hud = world.hud
	check(hud.modal.visible and hud.modal_kind == "names", "naming screen opens on a new game")
	hud._on_dim_input(_click())
	check(hud.modal.visible and hud.modal_kind == "names", "tapping outside does not dismiss it")
	var edits: Array = hud.modal_body.find_children("*", "LineEdit", true, false)
	check(edits.size() == 2, "two text fields: player and restaurant")
	var start: Button = null
	for b in hud.modal_body.find_children("*", "Button", true, false):
		if b.text == loc.t("BTN_START"):
			start = b
	check(start != null and start.disabled, "Start is disabled while the names are empty")
	edits[0].text = "Mali"
	edits[0].text_changed.emit("Mali")
	check(start.disabled, "Start stays disabled with one name")
	edits[1].text = "Sea Breeze"
	edits[1].text_changed.emit("Sea Breeze")
	check(not start.disabled, "Start enables with both names")
	loc.toggle()
	await process_frame
	edits = hud.modal_body.find_children("*", "LineEdit", true, false)
	check(edits[0].text == "Mali" and edits[1].text == "Sea Breeze", "typed names survive a language change")
	start = null
	for b in hud.modal_body.find_children("*", "Button", true, false):
		if b.text == loc.t("BTN_START"):
			start = b
	start.pressed.emit()
	check(not hud.modal.visible and gs.player_name == "Mali" and gs.restaurant_name == "Sea Breeze", "Start saves the names and closes")
	check(hud.message_key == "MSG_WELCOME" and hud.message_label.text.contains("Mali") and hud.message_label.text.contains("Sea Breeze"), "the welcome line speaks the names")
	check(loc.t("MSG_WELCOME").count("%s") == 2, "the welcome line is a two-name template in both languages")
	loc.set_language("th")
	check(loc.t("MSG_WELCOME").count("%s") == 2, "Thai welcome line takes the same two names")

	world._on_reset()
	await process_frame
	check(hud.modal.visible and hud.modal_kind == "names" and not gs.has_names(), "resetting the game asks for names again")
	world.queue_free()
	await process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))
	if failures == 0:
		print("PASS: names (naming screen, limits, saves, welcome line, reset)")
		quit(0)
	else:
		printerr("%d check(s) failed" % failures)
		quit(1)

func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.pressed = true
	e.button_index = MOUSE_BUTTON_LEFT
	return e
