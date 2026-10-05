class_name Catalog
extends RefCounted

# Scenes the player works in; each has its own map (see SceneLayout).
const ZONES: Array[String] = ["restaurant", "farm"]

# Game rules only; how things look (colours, sprite sizing) is in scripts/visuals/art_catalog.gd.
# Placeable keys are also art file names under assets/ (see docs/ASSETS.md).
# "area" is the kind of land an item may stand on (see Island).
# "size" is the footprint in UNITS: finer than a cell, Iso.SUB x Iso.SUB units per cell, so (4, 4) is a 2x2-cell table
# (owned by game rules: do not change it to fix a picture).
# "flat" objects are drawn like floor tiles instead of upright sprites.
# "surface" objects (tables) carry small things; "on": "surface" things (vases, cups) stand on a surface instead of the floor:
# they take no floor room and live in their own layer (WorldGrid.tops), still sized in units.
# "block" is where the thing stops walking: a Rect2i (x, y, w, h) in units inside the footprint, as it stands facing front.
# Without one the whole footprint blocks; Rect2i() (empty) means people walk over it (a plot). It is separate from "size"
# (the room it reserves) and from the picture (ArtCatalog.ART_BOX); a quarter turn turns the rectangle with the footprint.
# "rotatable" objects have a front: the player buys one and turns it (facing 0 front, 1 left, 2 back, 3 right).
const PLACEABLES := {
	"rest_table_small_01": {"area": "restaurant", "cost": 30, "size": Vector2i(4, 2), "name": "ITEM_TABLE", "surface": true},
	"rest_stove_01": {"area": "restaurant", "cost": 80, "size": Vector2i(4, 2), "name": "ITEM_STOVE", "rotatable": true},
	"rest_vase_small_01": {"area": "restaurant", "cost": 10, "size": Vector2i(1, 1), "name": "ITEM_VASE_SMALL", "on": "surface"},
	"rest_vase_large_01": {"area": "restaurant", "cost": 25, "size": Vector2i(2, 2), "name": "ITEM_VASE_LARGE", "on": "surface"},
	"farm_plot_01": {"area": "farm", "cost": 10, "size": Vector2i(4, 4), "name": "ITEM_PLOT", "flat": true, "block": Rect2i()},
	"farm_fence_01": {"area": "farm", "cost": 20, "size": Vector2i(2, 2), "name": "ITEM_FENCE"},
	"farm_coop_01": {"area": "farm", "cost": 120, "level": 2, "size": Vector2i(6, 6), "name": "ITEM_COOP"},
}

# time: seconds to grow. seed: coin cost per planting. yield: items per harvest.
const CROPS := {
	"wheat": {"time": 60.0, "seed": 2, "yield": 1, "xp": 1, "level": 1, "name": "CROP_WHEAT"},
	"tomato": {"time": 180.0, "seed": 6, "yield": 1, "xp": 3, "level": 2, "name": "CROP_TOMATO"},
	"cabbage": {"time": 300.0, "seed": 10, "yield": 1, "xp": 5, "level": 3, "name": "CROP_CABBAGE"},
}

# A coop turns 1 wheat into 1 egg after `time` seconds.
const COOP := {"feed": "wheat", "product": "egg", "time": 120.0, "xp": 3}

# Dishes the restaurant can cook. ingredients: items taken from the barn. time: seconds on a stove.
# price: coins paid by the customer. xp: given when served.
const RECIPES := {
	"wheat_porridge": {"name": "DISH_PORRIDGE", "ingredients": {"wheat": 2}, "time": 15.0, "price": 14, "xp": 2, "level": 1},
	"omelet": {"name": "DISH_OMELET", "ingredients": {"egg": 2}, "time": 20.0, "price": 40, "xp": 4, "level": 2},
	"tomato_soup": {"name": "DISH_TOMATO_SOUP", "ingredients": {"tomato": 2, "wheat": 1}, "time": 25.0, "price": 60, "xp": 6, "level": 2},
	"cabbage_salad": {"name": "DISH_SALAD", "ingredients": {"cabbage": 2}, "time": 30.0, "price": 100, "xp": 8, "level": 3},
}

# arrival_base: seconds between customers (shorter with reputation). patience: seconds a customer waits.
# tip_rate: share of the price given as a tip by a customer served instantly (less as patience runs out).
# counter_slots: finished dishes that can wait to be served.
const RESTAURANT := {"arrival_base": 20.0, "patience": 75.0, "tip_rate": 0.25, "counter_slots": 6}

# Things that block building until cleared.
const OBSTACLES := {
	"tree": {"cost": 30, "xp": 2, "item": "wood", "name": "OBS_TREE"},
	"rock": {"cost": 20, "xp": 2, "item": "stone", "name": "OBS_ROCK"},
	"bush": {"cost": 10, "xp": 1, "item": "", "name": "OBS_BUSH"},
}

const ITEMS := {
	"wood": {"sell": 3, "name": "ITEM_WOOD"},
	"stone": {"sell": 3, "name": "ITEM_STONE"},
	"wheat": {"sell": 4, "name": "CROP_WHEAT"},
	"tomato": {"sell": 14, "name": "CROP_TOMATO"},
	"cabbage": {"sell": 25, "name": "CROP_CABBAGE"},
	"egg": {"sell": 10, "name": "ITEM_EGG"},
}

# Level needed to place an item (default 1).
static func unlock_level(id: String) -> int:
	return int(PLACEABLES[id].get("level", 1))

static func size_of(id: String) -> Vector2i:
	return PLACEABLES[id].size

static func is_surface(id: String) -> bool:
	return bool(PLACEABLES.get(id, {}).get("surface", false))

# A thing that stands on a table, not on the floor.
static func is_top(id: String) -> bool:
	return PLACEABLES.get(id, {}).get("on", "") == "surface"

static func is_rotatable(id: String) -> bool:
	return bool(PLACEABLES.get(id, {}).get("rotatable", false))

# Footprint of `id` turned to `facing`: a sideways turn swaps width and height.
static func size_facing(id: String, facing: int) -> Vector2i:
	var sz: Vector2i = PLACEABLES[id].size
	return Vector2i(sz.y, sz.x) if facing % 2 == 1 else sz

# The walking-blocked part of `id` turned to `facing`, in units from the footprint's top-left corner (a quarter turn is
# clockwise on screen: front -> left -> back -> right). Empty when people can walk over it.
static func block_rect(id: String, facing: int = 0) -> Rect2i:
	var def: Dictionary = PLACEABLES[id]
	var sz: Vector2i = def.size
	var r: Rect2i = def.get("block", Rect2i(Vector2i.ZERO, sz))
	if r.size.x <= 0 or r.size.y <= 0:
		return Rect2i()
	return turn_rect(r, sz, facing)

# A rectangle inside a `sz` box after `facing` clockwise quarter turns of the box: (x, y) in a W x H box becomes (H - y - h, x) in a H x W box.
static func turn_rect(r: Rect2i, sz: Vector2i, facing: int) -> Rect2i:
	for _i in range(facing % 4):
		r = Rect2i(Vector2i(sz.y - r.position.y - r.size.y, r.position.x), Vector2i(r.size.y, r.size.x))
		sz = Vector2i(sz.y, sz.x)
	return r

# A turn keeps the middle of the thing where it is, so a thing can be turned in place. Footprints are counted in units, so when the
# width and depth differ by an odd number the middle falls between units and is rounded towards the top-left. To make four turns
# come back exactly (no drift), the top-left corner moves by +shift when turning to a left/right facing and by -shift back.
static func turn_shift(id: String) -> Vector2i:
	return shift_for_size(PLACEABLES[id].size)

static func shift_for_size(sz: Vector2i) -> Vector2i:
	return Vector2i(floori((sz.x - sz.y) / 2.0), floori((sz.y - sz.x) / 2.0))

# Top-left unit of `id` after it is turned to `new_facing` (the previous facing is `new_facing - 1`), from its top-left unit `origin`.
static func origin_after_turn(id: String, origin: Vector2i, new_facing: int) -> Vector2i:
	var shift := turn_shift(id)
	return origin + (shift if new_facing % 2 == 1 else -shift)

static func placeables_for(area: String) -> Array[String]:
	var out: Array[String] = []
	for id in PLACEABLES:
		if PLACEABLES[id].area == area:
			out.append(id)
	return out

# Art id for a crop stage: 1 sprout, 2 growing, 3 almost ripe, 4 ready.
static func crop_stage(progress: float) -> int:
	if progress >= 1.0:
		return 4
	return 1 + mini(2, int(progress * 3.0))
