extends Node

signal changed

const SAVE_PATH := "user://salvora.json"
const START_COINS := 500
const GRID_SIZE := Vector2i(12, 12)
const TEST_GRANT := 500

var coins: int = START_COINS
var language: String = ""
var grids: Dictionary = {}
var inventory: Inventory = Inventory.new(60)
var save_path: String = SAVE_PATH
var autosave: bool = true
var clock_override: float = -1.0

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

func _min_seed_cost() -> int:
	var lowest := 1 << 30
	for crop in Catalog.CROPS:
		lowest = mini(lowest, int(Catalog.CROPS[crop].seed))
	return lowest

func _farm_has(id: String) -> bool:
	return grid("farm").objects.values().has(id)

# True when the player has no coins, nothing to sell and nothing growing, so no action can ever earn money.
func is_broke() -> bool:
	return coins < _min_seed_cost() and inventory.total() == 0 and grid("farm").states.is_empty()

func grant_test_coins() -> void:
	coins += TEST_GRANT
	_commit()

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
	var cost: int = def.cost
	if id == "farm_plot_01" and is_broke() and not _farm_has("farm_plot_01"):
		cost = 0
	if coins < cost:
		return "no_coins"
	coins -= cost
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

func now() -> float:
	return clock_override if clock_override >= 0.0 else Time.get_unix_time_from_system()

func _elapsed(state: Dictionary) -> float:
	return maxf(0.0, now() - float(state.get("t", 0.0)))

# 0..1 while a plot is growing or a coop is producing, 1.0 when ready, -1.0 if idle or not a producer.
func progress(zone: String, c: Vector2i) -> float:
	var g := grid(zone)
	var st: Dictionary = g.states.get(c, {})
	if st.is_empty():
		return -1.0
	var id: String = g.objects.get(c, "")
	var total := 0.0
	if id == "farm_plot_01" and Catalog.CROPS.has(st.get("crop", "")):
		total = Catalog.CROPS[st.crop].time
	elif id == "farm_coop_01":
		total = Catalog.COOP.time
	if total <= 0.0:
		return -1.0
	return clampf(_elapsed(st) / total, 0.0, 1.0)

func seconds_left(zone: String, c: Vector2i) -> int:
	var p := progress(zone, c)
	if p < 0.0 or p >= 1.0:
		return 0
	var st: Dictionary = grid(zone).states[c]
	var id: String = grid(zone).objects[c]
	var total: float = Catalog.CROPS[st.crop].time if id == "farm_plot_01" else Catalog.COOP.time
	return ceili(total - _elapsed(st))

# One tap on a plot or coop. `seed_id` is the crop to plant if the plot is empty.
# Returns "planted", "harvested", "fed", "collected", "growing", "busy", "no_coins", "no_feed", "full" or "invalid".
func interact(zone: String, c: Vector2i, seed_id: String) -> String:
	var g := grid(zone)
	var id: String = g.objects.get(c, "")
	if id == "farm_plot_01":
		return _interact_plot(zone, c, seed_id)
	if id == "farm_coop_01":
		return _interact_coop(zone, c)
	return "invalid"

func _interact_plot(zone: String, c: Vector2i, seed_id: String) -> String:
	var g := grid(zone)
	if g.states.has(c):
		var st: Dictionary = g.states[c]
		if progress(zone, c) < 1.0:
			return "growing"
		var crop: Dictionary = Catalog.CROPS[st.crop]
		if inventory.add(st.crop, int(crop.yield)) == 0:
			return "full"
		g.states.erase(c)
		_commit()
		return "harvested"
	if not Catalog.CROPS.has(seed_id):
		return "invalid"
	var cost: int = Catalog.CROPS[seed_id].seed
	if seed_id == "wheat" and is_broke():
		cost = 0
	if coins < cost:
		return "no_coins"
	coins -= cost
	g.states[c] = {"crop": seed_id, "t": now()}
	_commit()
	return "planted"

func _interact_coop(zone: String, c: Vector2i) -> String:
	var g := grid(zone)
	if g.states.has(c):
		if progress(zone, c) < 1.0:
			return "busy"
		if inventory.add(Catalog.COOP.product, 1) == 0:
			return "full"
		g.states.erase(c)
		_commit()
		return "collected"
	if not inventory.remove(Catalog.COOP.feed, 1):
		return "no_feed"
	g.states[c] = {"t": now()}
	_commit()
	return "fed"

func sell(item: String, amount: int) -> int:
	if not Catalog.ITEMS.has(item):
		return 0
	var n := mini(amount, inventory.count(item))
	if n <= 0 or not inventory.remove(item, n):
		return 0
	var earned: int = n * int(Catalog.ITEMS[item].sell)
	coins += earned
	_commit()
	return earned

func sell_all() -> int:
	var total := 0
	for item in inventory.items.keys():
		total += sell(item, inventory.count(item))
	return total

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
