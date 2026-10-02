extends Node

signal changed

const SAVE_PATH := "user://salvora.json"
const START_COINS := 500
const GRID_SIZE := Vector2i(12, 12)

var coins: int = START_COINS
var language: String = ""
var grids: Dictionary = {}
var inventory: Inventory = Inventory.new(60)
var save_path: String = SAVE_PATH
var autosave: bool = true

func _ready() -> void:
	reset()
	load_game()

func reset() -> void:
	coins = START_COINS
	grids = {}
	for z in Catalog.ZONES:
		grids[z] = WorldGrid.new(GRID_SIZE, _start_cells())
	inventory = Inventory.new(60)

func _start_cells() -> Array:
	var cells: Array = []
	for y in range(4, 7):
		for x in range(4, 7):
			cells.append(Vector2i(x, y))
	return cells

func grid(zone: String) -> WorldGrid:
	return grids[zone]

func land_cost(zone: String) -> int:
	return 50 + 25 * grid(zone).bought_count()

func buy_land(zone: String, c: Vector2i) -> String:
	var g := grid(zone)
	if not g.can_buy(c):
		return "invalid"
	var cost := land_cost(zone)
	if coins < cost:
		return "no_coins"
	coins -= cost
	g.buy(c)
	_commit()
	return "ok"

func place_object(zone: String, c: Vector2i, id: String) -> String:
	var def = Catalog.PLACEABLES.get(id)
	if def == null or def.zone != zone:
		return "invalid"
	var g := grid(zone)
	if not g.in_bounds(c):
		return "invalid"
	if not g.is_owned(c):
		return "locked"
	if g.objects.has(c):
		return "occupied"
	if coins < def.cost:
		return "no_coins"
	coins -= def.cost
	g.place(c, id)
	_commit()
	return "ok"

func remove_object(zone: String, c: Vector2i) -> String:
	var id := grid(zone).remove(c)
	if id == "":
		return "empty"
	coins += int(Catalog.PLACEABLES[id].cost) / 2
	_commit()
	return "ok"

func refund_for(zone: String, c: Vector2i) -> int:
	var id: String = grid(zone).objects.get(c, "")
	return int(Catalog.PLACEABLES[id].cost) / 2 if id != "" else 0

func set_language(code: String) -> void:
	language = code
	_commit()

func _commit() -> void:
	if autosave:
		save_game()
	changed.emit()

func save_game() -> bool:
	var g := {}
	for z in grids:
		g[z] = grids[z].to_dict()
	return SaveStore.write(save_path, {
		"coins": coins, "language": language, "grids": g, "inventory": inventory.to_dict()})

func load_game() -> bool:
	var d := SaveStore.read(save_path)
	if d.is_empty():
		return false
	coins = maxi(0, int(d.get("coins", START_COINS)))
	language = str(d.get("language", ""))
	var gd = d.get("grids", {})
	if gd is Dictionary:
		for z in Catalog.ZONES:
			if gd.has(z) and gd[z] is Dictionary:
				grids[z].load_dict(gd[z])
	var inv = d.get("inventory", {})
	if inv is Dictionary:
		inventory.load_dict(inv)
	return true
