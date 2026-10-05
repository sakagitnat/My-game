class_name Restaurant
extends RefCounted

# The restaurant loop: customers arrive and sit at tables, order a dish, the player cooks it on a
# stove from barn ingredients, then serves it for coins, a tip, XP and reputation.
# `host` is GameState (left untyped so this script also compiles in headless tests).
signal customer_arrived(id: int)
signal customer_left(id: int)
signal dish_ready(dish: String)
signal served(id: int, price: int, tip: int)

const TABLE_ID := "rest_table_small_01"
const STOVE_ID := "rest_stove_01"

var host
var rng := RandomNumberGenerator.new()
var customers: Array = []
var counter: Array = []
var reputation: int = 0
var arrival_timer: float = 6.0
var next_id: int = 1

func _init(game) -> void:
	host = game
	rng.randomize()

func reset_state() -> void:
	customers.clear()
	counter.clear()
	reputation = 0
	arrival_timer = 6.0
	next_id = 1

func _grid() -> WorldGrid:
	return host.grid("restaurant")

func _origins(id: String) -> Array:
	var out: Array = []
	var g := _grid()
	for o in g.objects:
		if g.objects[o] == id:
			out.append(o)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y * 1000 + a.x < b.y * 1000 + b.x)
	return out

func tables() -> Array:
	return _origins(TABLE_ID)

func stoves() -> Array:
	return _origins(STOVE_ID)

func has_service() -> bool:
	return not tables().is_empty() and not stoves().is_empty()

# Two seats per table: one on each side. `cell` is the unit (Iso.SUB per cell) at the corner of the cell next to the table where the customer sits.
func seats() -> Array:
	var out: Array = []
	for t in tables():
		out.append({"table": t, "index": 0, "cell": t + Vector2i(-2, 0)})
		out.append({"table": t, "index": 1, "cell": t + Vector2i(3, 0)})
	return out

func free_seats() -> Array:
	var out: Array = []
	for s in seats():
		var taken := false
		for c in customers:
			if c.table == s.table and c.index == s.index:
				taken = true
				break
		if not taken:
			out.append(s)
	return out

func available_recipes() -> Array:
	var out: Array = []
	for id in Catalog.RECIPES:
		if host.level >= int(Catalog.RECIPES[id].level):
			out.append(id)
	return out

# Ingredients still missing for `dish` as {item: amount}.
func missing(dish: String) -> Dictionary:
	var out := {}
	var need: Dictionary = Catalog.RECIPES[dish].ingredients
	for item in need:
		var short: int = int(need[item]) - host.inventory.count(item)
		if short > 0:
			out[item] = short
	return out

func _stove_busy(origin: Vector2i) -> bool:
	return _grid().states.has(origin)

func _cooking_count() -> int:
	var n := 0
	for o in stoves():
		if _stove_busy(o):
			n += 1
	return n

func is_cooking(dish: String) -> bool:
	for o in stoves():
		if _grid().states.get(o, {}).get("dish", "") == dish:
			return true
	return false

# "ok", "level", "no_stove" (none placed), "busy" (all in use), "counter_full" or "no_ingredients".
func can_cook(dish: String) -> String:
	if not Catalog.RECIPES.has(dish):
		return "invalid"
	if host.level < int(Catalog.RECIPES[dish].level):
		return "level"
	var all := stoves()
	if all.is_empty():
		return "no_stove"
	if _cooking_count() >= all.size():
		return "busy"
	if counter.size() + _cooking_count() >= int(Catalog.RESTAURANT.counter_slots):
		return "counter_full"
	if not missing(dish).is_empty():
		return "no_ingredients"
	return "ok"

func cook(dish: String) -> String:
	var result := can_cook(dish)
	if result != "ok":
		return result
	for item in Catalog.RECIPES[dish].ingredients:
		host.inventory.remove(item, int(Catalog.RECIPES[dish].ingredients[item]))
	for o in stoves():
		if not _stove_busy(o):
			_grid().states[o] = {"dish": dish, "t": host.now()}
			break
	return "ok"

# Dishes that finished cooking move from the stoves to the counter. True if anything moved.
func _collect_finished() -> bool:
	var moved := false
	for o in stoves():
		var st: Dictionary = _grid().states.get(o, {})
		if st.is_empty() or host.progress("restaurant", o) < 1.0:
			continue
		if counter.size() >= int(Catalog.RESTAURANT.counter_slots):
			break
		counter.append(st.dish)
		_grid().states.erase(o)
		dish_ready.emit(st.dish)
		moved = true
	return moved

func _arrival_interval() -> float:
	var boost := 1.0 + float(mini(reputation, 50)) / 50.0
	return float(Catalog.RESTAURANT.arrival_base) / boost * rng.randf_range(0.7, 1.3)

func _pick_dish() -> String:
	var options := available_recipes()
	var cookable: Array = []
	for d in options:
		if missing(d).is_empty():
			cookable.append(d)
	if not cookable.is_empty() and rng.randf() < 0.7:
		options = cookable
	return options[rng.randi_range(0, options.size() - 1)]

func _spawn() -> bool:
	var free := free_seats()
	if free.is_empty():
		return false
	var seat: Dictionary = free[rng.randi_range(0, free.size() - 1)]
	var p := float(Catalog.RESTAURANT.patience)
	var c := {"id": next_id, "table": seat.table, "index": seat.index, "seat_cell": seat.cell,
		"dish": _pick_dish(), "patience": p, "max_patience": p}
	next_id += 1
	customers.append(c)
	customer_arrived.emit(c.id)
	return true

# Advances time. Returns true when something visible changed (arrival, departure, dish ready).
func tick(dt: float) -> bool:
	var changed := _collect_finished()
	var table_list := tables()
	for i in range(customers.size() - 1, -1, -1):
		if not table_list.has(customers[i].table):
			# Their table was sold or moved: they leave, which is not the player's fault.
			var gone: int = customers[i].id
			customers.remove_at(i)
			customer_left.emit(gone)
			changed = true
	for i in range(customers.size() - 1, -1, -1):
		customers[i].patience -= dt
		if customers[i].patience <= 0.0:
			var id: int = customers[i].id
			customers.remove_at(i)
			reputation = maxi(0, reputation - 1)
			customer_left.emit(id)
			changed = true
	if has_service() and host.shop_open():
		arrival_timer -= dt
		if arrival_timer <= 0.0:
			arrival_timer = _arrival_interval()
			changed = _spawn() or changed
	return changed

# {"result": "ok", "price", "tip", "dish"} or {"result": "invalid" | "no_dish"}.
func serve(id: int) -> Dictionary:
	for i in range(customers.size()):
		var c: Dictionary = customers[i]
		if c.id != id:
			continue
		var at := counter.find(c.dish)
		if at == -1:
			return {"result": "no_dish"}
		counter.remove_at(at)
		var recipe: Dictionary = Catalog.RECIPES[c.dish]
		var price: int = recipe.price
		var tip := int(round(price * float(Catalog.RESTAURANT.tip_rate) * clampf(c.patience / c.max_patience, 0.0, 1.0)))
		host.coins += price + tip
		host.add_xp(int(recipe.xp))
		reputation += 1
		customers.remove_at(i)
		served.emit(id, price, tip)
		return {"result": "ok", "price": price, "tip": tip, "dish": c.dish}
	return {"result": "invalid"}

# Read-only copies for the renderer (see ViewState).
func snapshot_customers() -> Array:
	var out: Array = []
	for c in customers:
		out.append({"id": c.id, "seat_cell": c.seat_cell, "table": c.table, "index": c.index, "dish": c.dish,
			"patience_frac": clampf(c.patience / c.max_patience, 0.0, 1.0),
			"served_ready": counter.has(c.dish)})
	return out

func to_dict() -> Dictionary:
	return {"counter": counter.duplicate(), "reputation": reputation}

func load_dict(d: Dictionary) -> void:
	counter.clear()
	for dish in d.get("counter", []):
		if Catalog.RECIPES.has(str(dish)) and counter.size() < int(Catalog.RESTAURANT.counter_slots):
			counter.append(str(dish))
	reputation = maxi(0, int(d.get("reputation", 0)))
