extends Node

signal changed
signal leveled_up(new_level: int)

const SAVE_PATH := "user://salvora.json"
const START_COINS := 500
const LAND_BASE_COST := 150
const LAND_STEP_COST := 100
const LAND_XP := 5
const PLACE_XP := 2
const TEST_GRANT := 500
const BARN_STEP := 30
const BARN_BASE_COST := 100
const OBSTACLE_SEED := 20261002
const NAME_MAX := 14
const CLEAR_MARGIN := 1  # cells kept free of trees inside each starting block, measured from the block edge
const FLOOR_COST := 60   # turning an owned land block of the restaurant into indoor floor

var coins: int = START_COINS
var xp: int = 0
var level: int = 1
var language: String = ""
var player_name: String = ""
var restaurant_name: String = ""
var ask_names: bool = true  # tests turn this off so the naming screen stays out of the way
var grids: Dictionary = {}
var inventory: Inventory = Inventory.new(60)
var save_path: String = SAVE_PATH
var autosave: bool = true
var clock_override: float = -1.0
var spawn_obstacles: bool = true
var restaurant_active: bool = true
var restaurant: Restaurant = Restaurant.new(self)
var layouts: Dictionary = {}

func _ready() -> void:
	load_default_layouts()
	reset()
	load_game()

func _process(delta: float) -> void:
	if restaurant_active and restaurant.tick(delta):
		_commit()

func reset() -> void:
	restaurant.reset_state()
	coins = START_COINS
	xp = 0
	level = 1
	grids = {}
	for z in Catalog.ZONES:
		build_zone(z)
	inventory = Inventory.new(60)
	player_name = ""
	restaurant_name = ""

# A fresh grid for one scene from its map: starting blocks, blocks for sale, the map's trees, rocks and objects.
# The map editor calls this after every edit; whatever the player had placed there is gone.
func build_zone(zone: String) -> void:
	var l := layout_for(zone)
	grids[zone] = WorldGrid.new(l.cells, l.starts, l.sale_parcels())
	_place_map_objects(zone)
	if spawn_obstacles:
		if l.scatter:
			scatter_obstacles(zone)
		else:
			_place_map_obstacles(zone)
	if zone == "restaurant":
		restaurant.customers.clear()

func layout_for(zone: String) -> SceneLayout:
	return layouts[zone]

# The owner's edited maps if there are any, else the ones that ship with the game.
func load_default_layouts() -> void:
	layouts = {}
	for z in Catalog.ZONES:
		layouts[z] = MapStore.load_layout(z)

# Tests swap in plain 30x30 plots where every block is for sale and takes every item.
func use_sandbox_layouts() -> void:
	layouts = {"restaurant": SceneLayout.sandbox(), "farm": SceneLayout.sandbox()}

# Whole cells between a cell and the water (0 on the outermost ring of a square plot, -1 in the water).
func edge_distance(zone: String, c: Vector2i) -> int:
	return layout_for(zone).edge_distance(c)

# True for cells inside the middle of a starting block (kept clear so the player can build at once).
func in_start_clearing(zone: String, c: Vector2i) -> bool:
	var l := layout_for(zone)
	for p in l.starts:
		var r := Rect2i(p * WorldGrid.PARCEL + Vector2i.ONE * CLEAR_MARGIN, Vector2i.ONE * (WorldGrid.PARCEL - 2 * CLEAR_MARGIN))
		if r.has_point(c):
			return true
	return false

# The map's own trees and rocks, wherever they stand on dry ground.
func _place_map_obstacles(zone: String) -> void:
	var g := grid(zone)
	var l := layout_for(zone)
	for o in l.obstacles:
		var c := Vector2i(int(o[0]), int(o[1]))
		if l.is_solid(c) and not g.cell_occupied(c):
			g.blocked[c] = str(o[2])

# Furniture and other objects the map starts with (free, not owned-land checked: the owner put them there). Origins are in units.
func _place_map_objects(zone: String) -> void:
	var g := grid(zone)
	for o in layout_for(zone).objects:
		var id := str(o[2])
		var sz: Vector2i = Catalog.size_of(id)
		var origin := Vector2i(int(o[0]), int(o[1]))
		if g.footprint_in_bounds(origin, sz) and g.footprint_free(origin, sz):
			g.objects[origin] = id
			g.footprints[origin] = sz
			for c in g.cells_of(origin, sz):
				g.occupied[c] = origin

# Tests only (layout.scatter): fills free land with random trees, rocks and bushes, leaving the starting blocks clear.
func scatter_obstacles(zone: String) -> void:
	var g := grid(zone)
	var l := layout_for(zone)
	var seed_v := OBSTACLE_SEED + (7919 if zone == "farm" else 0)
	for y in range(g.size.y):
		for x in range(g.size.x):
			var c := Vector2i(x, y)
			if g.cell_occupied(c) or in_start_clearing(zone, c) or l.edge_distance(c) < 3 or not l.is_solid(c):
				continue
			var forest := smoothstep(0.5, 0.78, Noise2D.value(x * 0.2, y * 0.2, seed_v))
			var wild := 0.0 if g.is_owned(c) else 0.04
			var chance := (0.02 + wild) + 0.30 * forest
			if Noise2D.hash2(x, y, seed_v + 1) >= chance:
				continue
			var r := Noise2D.hash2(x, y, seed_v + 2)
			g.blocked[c] = "tree" if r < 0.55 else ("rock" if r < 0.82 else "bush")

# Cell in the middle of the starting shop (used to centre the camera).
func start_cell() -> Vector2i:
	return layout_for("restaurant").start_cell()

# Same for the starting farm block.
func farm_start_cell() -> Vector2i:
	return layout_for("farm").start_cell()

func xp_for_next() -> int:
	return 30 + 20 * (level - 1)

func level_up_reward(lv: int) -> int:
	return 20 * lv

# Callers must _commit() afterwards.
func add_xp(amount: int) -> void:
	xp += maxi(0, amount)
	while xp >= xp_for_next():
		xp -= xp_for_next()
		level += 1
		coins += level_up_reward(level)
		leveled_up.emit(level)

func grid(zone: String) -> WorldGrid:
	return grids[zone]

func land_cost(zone: String) -> int:
	return LAND_BASE_COST + LAND_STEP_COST * grid(zone).bought_count()

# Buys the whole land block containing cell `c`.
func buy_land(zone: String, c: Vector2i) -> String:
	var g := grid(zone)
	var parcel := WorldGrid.parcel_of(c)
	if not g.in_bounds(c) or not g.can_buy_parcel(parcel):
		return "invalid"
	var cost := land_cost(zone)
	if coins < cost:
		return "no_coins"
	coins -= cost
	g.buy_parcel(parcel)
	add_xp(LAND_XP)
	_commit()
	return "ok"

# Turns an owned land block of the restaurant into indoor floor or back into grass. Returns "ok", "invalid",
# "locked" (not owned), "fixed" (a block owned from the start), "same" (already so) or "no_coins".
func set_floor(zone: String, c: Vector2i, floor_on: bool) -> String:
	if zone != "restaurant":
		return "invalid"
	var g := grid(zone)
	var parcel := WorldGrid.parcel_of(c)
	var l := layout_for(zone)
	if not g.in_bounds(c):
		return "invalid"
	if not g.owned_parcels.has(parcel):
		return "locked"
	if l.is_start_parcel(parcel):
		return "fixed"
	if g.has_floor(parcel) == floor_on:
		return "same"
	if floor_on:
		if coins < FLOOR_COST:
			return "no_coins"
		coins -= FLOOR_COST
	g.set_floor(parcel, floor_on)
	_commit()
	return "ok"

func _min_seed_cost() -> int:
	var lowest := 1 << 30
	for crop in Catalog.CROPS:
		lowest = mini(lowest, int(Catalog.CROPS[crop].seed))
	return lowest

func _farm_has(id: String) -> bool:
	for z in grids:
		if grids[z].objects.values().has(id):
			return true
	return false

# True when the player has no coins, nothing to sell and nothing growing, so no action can ever earn money.
func is_broke() -> bool:
	if coins >= _min_seed_cost() or inventory.total() > 0:
		return false
	for z in grids:
		if not grids[z].states.is_empty():
			return false
	return true

# The restaurant and the farm are one map when the main map takes every item ("any"); otherwise the farm is its own scene.
func has_farm_zone() -> bool:
	return layout_for("restaurant").area != "any"

# Items that can be bought and placed in a scene.
func placeables_in(zone: String) -> Array[String]:
	if layout_for(zone).area == "any":
		var out: Array[String] = []
		for id in Catalog.PLACEABLES:
			out.append(id)
		return out
	return Catalog.placeables_for(zone)

func grant_test_coins() -> void:
	coins += TEST_GRANT
	_commit()

# Top-left unit of a footprint of `sz` units centred on the tapped unit `c`.
func footprint_origin(c: Vector2i, sz: Vector2i) -> Vector2i:
	return c - Vector2i(floori((sz.x - 1) / 2.0), floori((sz.y - 1) / 2.0))

# Why `id` can or cannot be placed with a footprint centred on unit `c`: "ok", "invalid", "level", "locked", "occupied", "area" or "no_coins".
func check_place(zone: String, c: Vector2i, id: String, facing: int = 0) -> String:
	var def = Catalog.PLACEABLES.get(id)
	if def == null or not (def.area == zone or layout_for(zone).area == "any"):
		return "invalid"
	if level < Catalog.unlock_level(id):
		return "level"
	var g := grid(zone)
	var sz: Vector2i = Catalog.size_facing(id, facing)
	var origin := footprint_origin(c, sz)
	if not g.footprint_in_bounds(origin, sz):
		return "invalid"
	if not _footprint_solid(zone, origin, sz):
		return "invalid"
	if not _footprint_in_area(zone, origin, sz, str(def.area)):
		return "area"
	if not g.footprint_owned(origin, sz):
		return "locked"
	if Catalog.is_top(id):
		# stands on a table: the floor under it is not its business, only the surface and other things on it
		var ts := g.top_status(origin, sz)
		if ts != "ok":
			return ts
	else:
		if g.footprint_blocked(origin, sz):
			return "blocked"
		if not g.footprint_free(origin, sz):
			return "occupied"
	if coins < place_cost(id):
		return "no_coins"
	return "ok"

# Nothing may stand in the water or on the waterline.
func _footprint_solid(zone: String, origin: Vector2i, sz: Vector2i) -> bool:
	for u in grid(zone).cells_of(origin, sz):
		if not layout_for(zone).is_solid(Iso.cell_of_unit(u)):
			return false
	return true

# Every cell of the footprint must lie on land meant for this kind of item.
func _footprint_in_area(zone: String, origin: Vector2i, sz: Vector2i, area: String) -> bool:
	for u in grid(zone).cells_of(origin, sz):
		if not layout_for(zone).allows(area, Iso.cell_of_unit(u)):
			return false
	return true

func place_cost(id: String) -> int:
	if id == "farm_plot_01" and is_broke() and not _farm_has("farm_plot_01"):
		return 0
	return int(Catalog.PLACEABLES[id].cost)

func place_object(zone: String, c: Vector2i, id: String, facing: int = 0) -> String:
	if facing != 0 and not Catalog.is_rotatable(id):
		facing = 0
	var result := check_place(zone, c, id, facing)
	if result != "ok":
		return result
	var sz: Vector2i = Catalog.size_facing(id, facing)
	coins -= place_cost(id)
	if Catalog.is_top(id):
		grid(zone).place_top(footprint_origin(c, sz), id, sz)
	else:
		grid(zone).place(footprint_origin(c, sz), id, sz, facing)
	add_xp(PLACE_XP)
	_commit()
	return "ok"

# Whether the object covering `from_cell` fits with a footprint centred on `to_cell`: "ok", "empty", "invalid", "locked" or "occupied".
func check_move(zone: String, from_cell: Vector2i, to_cell: Vector2i, top: bool = false) -> String:
	var g := grid(zone)
	if top:
		return _check_move_top(zone, from_cell, to_cell)
	var origin := g.origin_at(from_cell)
	if origin == WorldGrid.NONE:
		return "empty"
	var sz: Vector2i = g.footprints[origin]
	var new_origin := footprint_origin(to_cell, sz)
	if not g.footprint_in_bounds(new_origin, sz):
		return "invalid"
	if not _footprint_solid(zone, new_origin, sz):
		return "invalid"
	if not _footprint_in_area(zone, new_origin, sz, str(Catalog.PLACEABLES[g.objects[origin]].area)):
		return "area"
	if not g.footprint_owned(new_origin, sz):
		return "locked"
	if g.footprint_blocked(new_origin, sz):
		return "blocked"
	for cell in g.cells_of(new_origin, sz):
		if g.occupied.has(cell) and g.occupied[cell] != origin:
			return "occupied"
	return "ok"

# A thing on a table (`top` moves): "ok", "empty", "invalid", "locked", "no_surface" or "occupied".
func _check_move_top(zone: String, from_cell: Vector2i, to_cell: Vector2i) -> String:
	var g := grid(zone)
	var origin := g.top_origin_at(from_cell)
	if origin == WorldGrid.NONE:
		return "empty"
	var sz: Vector2i = g.top_footprints[origin]
	var new_origin := footprint_origin(to_cell, sz)
	if not g.footprint_in_bounds(new_origin, sz):
		return "invalid"
	if not g.footprint_owned(new_origin, sz):
		return "locked"
	return g.top_status(new_origin, sz, origin)

# Moves the object covering `from_cell` so a footprint centred on `to_cell` holds it. Free of charge.
# With `top` it is the thing standing on a table there that moves (to another table, or elsewhere on the same one).
func move_object(zone: String, from_cell: Vector2i, to_cell: Vector2i, top: bool = false) -> String:
	var result := check_move(zone, from_cell, to_cell, top)
	if result != "ok":
		return result
	var g := grid(zone)
	if top:
		var t_origin := g.top_origin_at(from_cell)
		g.move_top(t_origin, footprint_origin(to_cell, g.top_footprints[t_origin]))
		_commit()
		return "ok"
	var origin := g.origin_at(from_cell)
	g.move(origin, footprint_origin(to_cell, g.footprints[origin]))
	_commit()
	return "ok"

# Whether the object at `origin` can turn a quarter turn: "ok", "empty", "fixed" (nothing to turn) or the reason it does not fit there.
func check_rotate(zone: String, origin: Vector2i) -> String:
	var g := grid(zone)
	if not g.objects.has(origin):
		return "empty"
	var id: String = g.objects[origin]
	if not Catalog.is_rotatable(id):
		return "fixed"
	var sz := Catalog.size_facing(id, (g.facing_at(origin) + 1) % 4)
	if not g.footprint_in_bounds(origin, sz):
		return "invalid"
	if not _footprint_solid(zone, origin, sz):
		return "invalid"
	if not _footprint_in_area(zone, origin, sz, str(Catalog.PLACEABLES[id].area)):
		return "area"
	if not g.footprint_owned(origin, sz):
		return "locked"
	if g.footprint_blocked(origin, sz):
		return "blocked"
	for cell in g.cells_of(origin, sz):
		if g.occupied.has(cell) and g.occupied[cell] != origin:
			return "occupied"
	return "ok"

# Turns the object at `origin` a quarter turn. Free of charge.
func rotate_object(zone: String, origin: Vector2i) -> String:
	var result := check_rotate(zone, origin)
	if result != "ok":
		return result
	var g := grid(zone)
	g.turn(origin, Catalog.size_facing(g.objects[origin], (g.facing_at(origin) + 1) % 4))
	_commit()
	return "ok"

# Pays to remove the tree, rock or bush on owned cell `c`. Wood and stone go to the barn when there is room.
func clear_obstacle(zone: String, c: Vector2i) -> String:
	var g := grid(zone)
	var kind: String = g.blocked.get(c, "")
	if kind == "":
		return "empty"
	if not g.is_owned(c):
		return "locked"
	var def: Dictionary = Catalog.OBSTACLES[kind]
	if coins < int(def.cost):
		return "no_coins"
	coins -= int(def.cost)
	g.blocked.erase(c)
	if def.item != "":
		inventory.add(def.item, 1)
	add_xp(int(def.xp))
	_commit()
	return "ok"

# Sells the object covering `c`, or with `top` the thing standing on a table there. Everything standing on a sold table is sold too.
func remove_object(zone: String, c: Vector2i, top: bool = false) -> String:
	var g := grid(zone)
	var refund := refund_for(zone, c, top)
	if top:
		if g.remove_top_at(c) == "":
			return "empty"
	elif g.remove_at(c) == "":
		return "empty"
	coins += refund
	_commit()
	return "ok"

func refund_for(zone: String, c: Vector2i, top: bool = false) -> int:
	var g := grid(zone)
	if top:
		var t: Vector2i = g.top_origin_at(c)
		return int(Catalog.PLACEABLES[g.tops[t]].cost) / 2 if t != WorldGrid.NONE else 0
	var origin := g.origin_at(c)
	if origin == WorldGrid.NONE:
		return 0
	var total := int(Catalog.PLACEABLES[g.objects[origin]].cost) / 2
	for t in g.tops_over(origin):
		total += int(Catalog.PLACEABLES[g.tops[t]].cost) / 2
	return total

func now() -> float:
	return clock_override if clock_override >= 0.0 else Time.get_unix_time_from_system()

func _elapsed(state: Dictionary) -> float:
	return maxf(0.0, now() - float(state.get("t", 0.0)))

# 0..1 while a plot is growing, a coop is producing or a stove is cooking, 1.0 when ready, -1.0 if idle or not a producer.
func progress(zone: String, c: Vector2i) -> float:
	var g := grid(zone)
	c = g.origin_at(c)
	var st: Dictionary = g.states.get(c, {})
	if st.is_empty():
		return -1.0
	var total := _total_time(g.objects.get(c, ""), st)
	if total <= 0.0:
		return -1.0
	return clampf(_elapsed(st) / total, 0.0, 1.0)

# Seconds a producer (plot, coop or stove) needs for the job described by `st`, or 0 if it is not a producer.
func _total_time(id: String, st: Dictionary) -> float:
	if id == "farm_plot_01" and Catalog.CROPS.has(st.get("crop", "")):
		return Catalog.CROPS[st.crop].time
	if id == "farm_coop_01":
		return Catalog.COOP.time
	if id == "rest_stove_01" and Catalog.RECIPES.has(st.get("dish", "")):
		return Catalog.RECIPES[st.dish].time
	return 0.0

func seconds_left(zone: String, c: Vector2i) -> int:
	var p := progress(zone, c)
	if p < 0.0 or p >= 1.0:
		return 0
	var o := grid(zone).origin_at(c)
	var st: Dictionary = grid(zone).states[o]
	return ceili(_total_time(grid(zone).objects[o], st) - _elapsed(st))

# One tap on a plot or coop. `seed_id` is the crop to plant if the plot is empty.
# Returns "planted", "harvested", "fed", "collected", "growing", "busy", "no_coins", "no_feed", "full" or "invalid".
func interact(zone: String, c: Vector2i, seed_id: String) -> String:
	var g := grid(zone)
	var origin := g.origin_at(c)
	var id: String = g.objects.get(origin, "")
	if id == "farm_plot_01":
		return _interact_plot(zone, origin, seed_id)
	if id == "farm_coop_01":
		return _interact_coop(zone, origin)
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
		add_xp(int(crop.xp))
		_commit()
		return "harvested"
	if not Catalog.CROPS.has(seed_id):
		return "invalid"
	if level < int(Catalog.CROPS[seed_id].level):
		return "level"
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
		add_xp(int(Catalog.COOP.xp))
		_commit()
		return "collected"
	if not inventory.remove(Catalog.COOP.feed, 1):
		return "no_feed"
	g.states[c] = {"t": now()}
	_commit()
	return "fed"

# Starts cooking `dish` on a free stove using barn ingredients. See Restaurant.can_cook for result codes.
func cook_dish(dish: String) -> String:
	var result := restaurant.cook(dish)
	if result == "ok":
		_commit()
	return result

# Serves the finished dish at the counter to customer `id`. Returns the Restaurant.serve result dictionary.
func serve_customer(id: int) -> Dictionary:
	var result := restaurant.serve(id)
	if result.result == "ok":
		_commit()
	return result

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

func barn_upgrade_cost() -> int:
	return BARN_BASE_COST * (1 + (inventory.capacity - 60) / BARN_STEP)

func upgrade_barn() -> String:
	var cost := barn_upgrade_cost()
	if coins < cost:
		return "no_coins"
	coins -= cost
	inventory.capacity += BARN_STEP
	_commit()
	return "ok"

func has_names() -> bool:
	return player_name != "" and restaurant_name != ""

# Names are trimmed and limited to NAME_MAX characters. Returns "ok" or "empty".
func set_names(player: String, shop: String) -> String:
	var p := player.strip_edges().left(NAME_MAX)
	var r := shop.strip_edges().left(NAME_MAX)
	if p == "" or r == "":
		return "empty"
	player_name = p
	restaurant_name = r
	_commit()
	return "ok"

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
		"coins": coins, "xp": xp, "level": level, "language": language, "player_name": player_name, "restaurant_name": restaurant_name, "grids": g, "inventory": inventory.to_dict(), "restaurant": restaurant.to_dict()})

func load_game() -> bool:
	var d := SaveStore.read(save_path)
	if d.is_empty():
		return false
	coins = maxi(0, int(d.get("coins", START_COINS)))
	level = maxi(1, int(d.get("level", 1)))
	xp = clampi(int(d.get("xp", 0)), 0, xp_for_next() - 1)
	language = str(d.get("language", ""))
	player_name = str(d.get("player_name", "")).left(NAME_MAX)
	restaurant_name = str(d.get("restaurant_name", "")).left(NAME_MAX)
	var gd = d.get("grids", {})
	if gd is Dictionary:
		for z in Catalog.ZONES:
			if gd.has(z) and gd[z] is Dictionary:
				var loaded: bool = grids[z].load_dict(gd[z])  # old-format saves keep a fresh grid
				if loaded and not gd[z].has("obstacles") and spawn_obstacles:
					scatter_obstacles(z)
	var inv = d.get("inventory", {})
	if inv is Dictionary:
		inventory.load_dict(inv)
	var rest = d.get("restaurant", {})
	if rest is Dictionary:
		restaurant.load_dict(rest)
	return true
