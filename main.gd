extends Node2D

const SAVE_PATH = "user://tavern.json"
const DISHES = ["SOUP", "BREAD", "JUICE"]
const PRICES = [18, 14, 12]
var coins: int = 0
var served: int = 0
var level: int = 1
var stock: Array[int] = [0, 0, 0]
var cooking: int = -1
var cook_time: float = 0.0
var arrival: float = 4.0
var customers: Array[Dictionary] = []
var seats: Array[Vector2] = [Vector2(350, 370), Vector2(580, 370), Vector2(465, 480), Vector2(695, 480)]
var message: String = "Tap a dish to cook. Tap a guest to serve."
var hud: Label
var note: Label
var buttons: Array[Button] = []
var upgrade_button: Button

func _ready() -> void:
	load_game()
	var ui = CanvasLayer.new()
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(36, 28)
	hud.add_theme_font_size_override("font_size", 30)
	ui.add_child(hud)
	var title = Label.new()
	title.text = "TINY TAVERN  /  kitchen prototype"
	title.position = Vector2(36, 75)
	title.modulate = Color("c7ab80")
	ui.add_child(title)
	note = Label.new()
	note.position = Vector2(36, 605)
	note.add_theme_font_size_override("font_size", 20)
	ui.add_child(note)
	for i in range(3):
		var b = Button.new()
		b.position = Vector2(36 + i * 215, 655)
		b.size = Vector2(200, 74)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(start_cooking.bind(i))
		ui.add_child(b)
		buttons.append(b)
	upgrade_button = Button.new()
	upgrade_button.position = Vector2(735, 655)
	upgrade_button.size = Vector2(330, 74)
	upgrade_button.pressed.connect(upgrade)
	ui.add_child(upgrade_button)
	spawn_customer()
	spawn_customer()
	refresh()

func refresh() -> void:
	hud.text = "GOLD  %d     SERVED  %d     KITCHEN  Lv.%d" % [coins, served, level]
	note.text = message
	for i in range(3):
		buttons[i].text = "%s   ×%d\nCook • free" % [DISHES[i], stock[i]]
		buttons[i].disabled = cooking != -1
	upgrade_button.text = "Faster kitchen • %d gold" % (level * 60)
	upgrade_button.disabled = coins < level * 60
	queue_redraw()

func start_cooking(dish: int) -> void:
	if cooking != -1:
		return
	cooking = dish
	cook_time = maxf(0.8, 3.5 - (level - 1) * 0.4)
	message = "Cooking %s…" % DISHES[dish]
	refresh()

func upgrade() -> void:
	var cost = level * 60
	if coins < cost:
		return
	coins -= cost
	level += 1
	message = "Kitchen upgraded! Cooking is faster."
	save_game()
	refresh()

func spawn_customer() -> void:
	for seat in range(seats.size()):
		var occupied = false
		for c in customers:
			if c.seat == seat:
				occupied = true
		if not occupied:
			customers.append({"seat": seat, "dish": randi_range(0, 2), "patience": 45.0, "color": Color.from_hsv(randf(), 0.35, 0.95)})
			return

func serve(seat: int) -> void:
	for i in range(customers.size()):
		var c = customers[i]
		if c.seat != seat:
			continue
		var dish: int = c.dish
		if stock[dish] == 0:
			message = "This guest wants %s. Cook it first." % DISHES[dish]
		else:
			stock[dish] -= 1
			coins += PRICES[dish]
			served += 1
			customers.remove_at(i)
			message = "Thank you! +%d gold" % PRICES[dish]
			save_game()
		refresh()
		return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(seats.size()):
			if event.position.distance_to(seats[i] + Vector2(0, -65)) < 75:
				serve(i)
				return

func _process(delta: float) -> void:
	arrival -= delta
	if arrival <= 0:
		arrival = 7.0
		spawn_customer()
	if cooking != -1:
		cook_time -= delta
		if cook_time <= 0:
			stock[cooking] += 1
			message = "%s ready! Tap the matching guest." % DISHES[cooking]
			cooking = -1
			refresh()
	for i in range(customers.size() - 1, -1, -1):
		customers[i].patience -= delta
		if customers[i].patience <= 0:
			customers.remove_at(i)
			message = "A guest left. Prepare food before the next arrival."
			refresh()
	queue_redraw()

func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"coins": coins, "served": served, "level": level}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		coins = maxi(0, int(data.get("coins", 0)))
		served = maxi(0, int(data.get("served", 0)))
		level = maxi(1, int(data.get("level", 1)))

func poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func tabletop(p: Vector2, width: float, depth: float) -> void:
	var a = p + Vector2(-width, 0)
	var b = p + Vector2(0, -depth)
	var c = p + Vector2(width, 0)
	var d = p + Vector2(0, depth)
	poly([a, d, d + Vector2(0, 18), a + Vector2(0, 18)], Color("75412e"))
	poly([d, c, c + Vector2(0, 18), d + Vector2(0, 18)], Color("4d302b"))
	poly([a, b, c, d], Color("bc7948"))
	draw_polyline(PackedVector2Array([a, b, c, d, a]), Color("edb576"), 2)

func _draw() -> void:
	# Original procedural artwork, no external asset dependencies.
	poly([Vector2(120, 345), Vector2(550, 130), Vector2(980, 345), Vector2(550, 560)], Color("bc824d"))
	poly([Vector2(120, 345), Vector2(550, 560), Vector2(550, 585), Vector2(120, 370)], Color("674537"))
	poly([Vector2(550, 560), Vector2(980, 345), Vector2(980, 370), Vector2(550, 585)], Color("49312d"))
	for i in range(1, 14):
		var t = float(i) / 14
		draw_line(Vector2(120, 345).lerp(Vector2(550, 130), t), Vector2(550, 560).lerp(Vector2(980, 345), t), Color("a36840"), 2)
	poly([Vector2(120, 345), Vector2(550, 130), Vector2(550, 35), Vector2(120, 250)], Color("5b4540"))
	poly([Vector2(550, 130), Vector2(980, 345), Vector2(980, 250), Vector2(550, 35)], Color("40383b"))
	for i in range(6):
		var p = Vector2(160 + i * 72, 325 - i * 36)
		draw_line(p, p + Vector2(0, -95), Color("956449"), 11)
	for p in [Vector2(250, 247), Vector2(435, 154), Vector2(690, 151), Vector2(875, 243)]:
		draw_circle(p, 25, Color("705238"))
		draw_circle(p, 17, Color("ffd88b"))
		draw_line(p + Vector2(-11, 0), p + Vector2(11, 0), Color("825533"), 4)
		draw_line(p + Vector2(0, -16), p + Vector2(0, 16), Color("825533"), 4)
	tabletop(Vector2(770, 294), 135, 48)
	for x in range(3):
		var p = Vector2(725 + x * 47, 275 + x * 17)
		draw_circle(p, 15, Color("d8bb8b"))
		draw_circle(p, 11, [Color("df9253"), Color("eac47d"), Color("a0cc94")][x])
	for p in seats:
		poly([p + Vector2(-80, 0), p + Vector2(0, -40), p + Vector2(80, 0), p + Vector2(0, 40)], Color("883f44"))
		tabletop(p, 66, 30)
		draw_circle(p + Vector2(0, -10), 8, Color("ffdb95"))
	for c in customers:
		var p: Vector2 = seats[c.seat] + Vector2(0, -65)
		draw_ellipse_shadow(p)
		draw_line(p + Vector2(-8, 17), p + Vector2(-8, 27), Color("332b36"), 9)
		draw_line(p + Vector2(8, 17), p + Vector2(8, 27), Color("332b36"), 9)
		draw_circle(p + Vector2(0, 8), 18, c.color)
		draw_circle(p + Vector2(0, -17), 22, Color("473442"))
		draw_circle(p + Vector2(0, -12), 17, Color("f6d4ae"))
		draw_circle(p + Vector2(-6, -13), 2.5, Color("302e3d"))
		draw_circle(p + Vector2(6, -13), 2.5, Color("302e3d"))
		poly([p + Vector2(-27, -29), p + Vector2(0, -62), p + Vector2(26, -29)], c.color.darkened(0.25))
		draw_style_box(bubble(), Rect2(p + Vector2(-45, -100), Vector2(90, 32)))
		draw_string(ThemeDB.fallback_font, p + Vector2(-34, -77), DISHES[c.dish], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("3d3030"))
		draw_rect(Rect2(p + Vector2(-30, 34), Vector2(60, 5)), Color("382b31"))
		draw_rect(Rect2(p + Vector2(-30, 34), Vector2(60 * clampf(c.patience / 45.0, 0, 1), 5)), Color("a9d697"))
	if cooking != -1:
		draw_string(ThemeDB.fallback_font, Vector2(690, 355), "Cooking %s  %.1fs" % [DISHES[cooking], maxf(0, cook_time)], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("ffe4b1"))

func bubble() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("ffebcb")
	style.set_corner_radius_all(8)
	return style

func draw_ellipse_shadow(p: Vector2) -> void:
	draw_set_transform(p + Vector2(0, 29), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 27, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
