class_name Goals
extends RefCounted

# The goal chain: one goal at a time, shown on the HUD, that walks a new player through the game (harvest, cook, serve, build)
# and then keeps giving them something to aim for. A finished goal waits for the player to claim its reward; the next one
# starts then. After the written list, "serve more customers" goals go on forever, each a little bigger.
#
# A goal measures one of:
#   "stat": a running count kept by GameState (harvested, planted, cooked, served, eggs, land, harvested_<crop>, cooked_<dish>),
#           counted from when the goal started, so earlier play does not count;
#   "count": how many of a placeable stand on the map now;
#   "level" / "rep": the player's level / the restaurant's reputation now.
# "text" is a strings.json key with %d for the target.
const LIST := [
	{"id": "harvest", "text": "GOAL_HARVEST", "stat": "harvested", "n": 2, "coins": 20, "xp": 3},
	{"id": "cook", "text": "GOAL_COOK", "stat": "cooked", "n": 1, "coins": 20, "xp": 3},
	{"id": "serve", "text": "GOAL_SERVE", "stat": "served", "n": 3, "coins": 40, "xp": 5},
	{"id": "plant", "text": "GOAL_PLANT", "stat": "planted", "n": 4, "coins": 30, "xp": 4},
	{"id": "tables", "text": "GOAL_TABLES", "count": "rest_table_small_01", "n": 3, "coins": 40, "xp": 5},
	{"id": "level2", "text": "GOAL_LEVEL", "level": true, "n": 2, "coins": 50, "xp": 0},
	{"id": "coop", "text": "GOAL_COOP", "count": "farm_coop_01", "n": 1, "coins": 60, "xp": 6},
	{"id": "eggs", "text": "GOAL_EGGS", "stat": "eggs", "n": 2, "coins": 40, "xp": 5},
	{"id": "omelet", "text": "GOAL_OMELET", "stat": "cooked_omelet", "n": 1, "coins": 50, "xp": 6},
	{"id": "stoves", "text": "GOAL_STOVES", "count": "rest_stove_01", "n": 2, "coins": 60, "xp": 6},
	{"id": "tomato", "text": "GOAL_TOMATO", "stat": "harvested_tomato", "n": 4, "coins": 60, "xp": 6},
	{"id": "soup", "text": "GOAL_SOUP", "stat": "cooked_tomato_soup", "n": 2, "coins": 80, "xp": 8},
	{"id": "serve10", "text": "GOAL_SERVE", "stat": "served", "n": 10, "coins": 100, "xp": 10},
	{"id": "land", "text": "GOAL_LAND", "stat": "land", "n": 1, "coins": 100, "xp": 10},
	{"id": "rep", "text": "GOAL_REP", "rep": true, "n": 25, "coins": 120, "xp": 12},
	{"id": "salad", "text": "GOAL_SALAD", "stat": "cooked_cabbage_salad", "n": 2, "coins": 150, "xp": 15},
]

var index: int = 0      # the goal being worked on (past the list: the endless ones)
var base: int = 0       # the stat's value when this goal started

# The goal at `i`: one from the list, or an endless "serve more" goal after it.
static func goal_at(i: int) -> Dictionary:
	if i < LIST.size():
		return LIST[i]
	var k := i - LIST.size()
	return {"id": "more%d" % k, "text": "GOAL_SERVE", "stat": "served", "n": 15 + 5 * k, "coins": 150 + 25 * k, "xp": 15 + k}

func current() -> Dictionary:
	return goal_at(index)

# How far along the goal is, measured on `host` (GameState: stats, level, restaurant, grid()).
static func measure(goal: Dictionary, host, start: int) -> int:
	if goal.has("stat"):
		return int(host.stats.get(goal.stat, 0)) - start
	if goal.has("count"):
		var n := 0
		for z in host.grids:
			for id in host.grids[z].objects.values():
				if id == goal.count:
					n += 1
		return n
	if goal.has("level"):
		return host.level
	if goal.has("rep"):
		return host.restaurant.reputation
	return 0

func progress(host) -> int:
	return mini(measure(current(), host, base), int(current().n))

func is_done(host) -> bool:
	return progress(host) >= int(current().n)

# Moves on to the next goal; a "stat" goal counts from now.
func advance(host) -> void:
	index += 1
	var g := current()
	base = int(host.stats.get(g.stat, 0)) if g.has("stat") else 0

func reset() -> void:
	index = 0
	base = 0

func to_dict() -> Dictionary:
	return {"index": index, "base": base}

func load_dict(d: Dictionary) -> void:
	index = maxi(0, int(d.get("index", 0)))
	base = maxi(0, int(d.get("base", 0)))
