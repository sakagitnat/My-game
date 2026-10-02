class_name Catalog
extends RefCounted

const ZONES: Array[String] = ["restaurant", "farm"]
const FLOOR := {"restaurant": "tile_wood_floor_01", "farm": "tile_grass_01"}
const LOCKED_TILE := "tile_locked_01"
const FLOOR_COLOR := {"restaurant": Color("c58a50"), "farm": Color("6fae58")}

# Placeable keys are also art file names under assets/ (see docs/ASSETS.md).
# "size" is the footprint in cells; art is scaled so its canvas width equals the footprint width.
# "flat" objects are drawn like floor tiles instead of upright sprites.
const PLACEABLES := {
	"rest_table_small_01": {"zone": "restaurant", "cost": 30, "size": Vector2i(2, 2), "name": "ITEM_TABLE", "color": Color("b8793f")},
	"rest_stove_01": {"zone": "restaurant", "cost": 80, "size": Vector2i(2, 2), "name": "ITEM_STOVE", "color": Color("6b6f78")},
	"farm_plot_01": {"zone": "farm", "cost": 10, "size": Vector2i(2, 2), "name": "ITEM_PLOT", "color": Color("6b4a2f"), "flat": true},
	"farm_fence_01": {"zone": "farm", "cost": 20, "size": Vector2i(1, 1), "name": "ITEM_FENCE", "color": Color("d9c7a0")},
	"farm_coop_01": {"zone": "farm", "cost": 120, "size": Vector2i(3, 3), "name": "ITEM_COOP", "color": Color("b5503c")},
}

# time: seconds to grow. seed: coin cost per planting. yield: items per harvest.
const CROPS := {
	"wheat": {"time": 60.0, "seed": 2, "yield": 1, "name": "CROP_WHEAT", "color": Color("e6c35c")},
	"tomato": {"time": 180.0, "seed": 6, "yield": 1, "name": "CROP_TOMATO", "color": Color("d9453b")},
	"cabbage": {"time": 300.0, "seed": 10, "yield": 1, "name": "CROP_CABBAGE", "color": Color("8fcf6a")},
}

# A coop turns 1 wheat into 1 egg after `time` seconds.
const COOP := {"feed": "wheat", "product": "egg", "time": 120.0}

const ITEMS := {
	"wheat": {"sell": 4, "name": "CROP_WHEAT"},
	"tomato": {"sell": 14, "name": "CROP_TOMATO"},
	"cabbage": {"sell": 25, "name": "CROP_CABBAGE"},
	"egg": {"sell": 10, "name": "ITEM_EGG"},
}

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
