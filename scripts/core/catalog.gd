class_name Catalog
extends RefCounted

const ZONES: Array[String] = ["restaurant", "farm"]

# Placeable keys are also art file names under assets/ (see docs/ASSETS.md).
# "size" is the footprint in cells; art is scaled so its canvas width equals the footprint width.
# "flat" objects are drawn like floor tiles instead of upright sprites.
const PLACEABLES := {
	"rest_table_small_01": {"zone": "restaurant", "cost": 30, "size": Vector2i(2, 2), "name": "ITEM_TABLE", "color": Color("b8793f")},
	"rest_stove_01": {"zone": "restaurant", "cost": 80, "level": 2, "size": Vector2i(2, 2), "name": "ITEM_STOVE", "color": Color("6b6f78")},
	"farm_plot_01": {"zone": "farm", "cost": 10, "size": Vector2i(2, 2), "name": "ITEM_PLOT", "color": Color("6b4a2f"), "flat": true},
	"farm_fence_01": {"zone": "farm", "cost": 20, "size": Vector2i(1, 1), "name": "ITEM_FENCE", "color": Color("d9c7a0")},
	"farm_coop_01": {"zone": "farm", "cost": 120, "level": 2, "size": Vector2i(3, 3), "name": "ITEM_COOP", "color": Color("b5503c")},
}

# time: seconds to grow. seed: coin cost per planting. yield: items per harvest.
const CROPS := {
	"wheat": {"time": 60.0, "seed": 2, "yield": 1, "xp": 1, "level": 1, "name": "CROP_WHEAT", "color": Color("e6c35c")},
	"tomato": {"time": 180.0, "seed": 6, "yield": 1, "xp": 3, "level": 2, "name": "CROP_TOMATO", "color": Color("d9453b")},
	"cabbage": {"time": 300.0, "seed": 10, "yield": 1, "xp": 5, "level": 3, "name": "CROP_CABBAGE", "color": Color("8fcf6a")},
}

# A coop turns 1 wheat into 1 egg after `time` seconds.
const COOP := {"feed": "wheat", "product": "egg", "time": 120.0, "xp": 3}

# Things that block building until cleared. `scale` is the sprite width in cells (art id `art`).
const OBSTACLES := {
	"tree": {"cost": 30, "xp": 2, "item": "wood", "name": "OBS_TREE", "art": "obs_tree_01", "scale": 2.6},
	"rock": {"cost": 20, "xp": 2, "item": "stone", "name": "OBS_ROCK", "art": "obs_rock_01", "scale": 1.3},
	"bush": {"cost": 10, "xp": 1, "item": "", "name": "OBS_BUSH", "art": "obs_bush_01", "scale": 1.6},
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

static func placeables_for(zone: String) -> Array[String]:
	var out: Array[String] = []
	for id in PLACEABLES:
		if PLACEABLES[id].zone == zone:
			out.append(id)
	return out

# Art id for a crop stage: 1 sprout, 2 growing, 3 almost ripe, 4 ready.
static func crop_stage(progress: float) -> int:
	if progress >= 1.0:
		return 4
	return 1 + mini(2, int(progress * 3.0))
