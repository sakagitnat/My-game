class_name Catalog
extends RefCounted

const ZONES: Array[String] = ["restaurant", "farm"]
const FLOOR := {"restaurant": "tile_wood_floor_01", "farm": "tile_grass_01"}
const LOCKED_TILE := "tile_locked_01"
const FLOOR_COLOR := {"restaurant": Color("c58a50"), "farm": Color("6fae58")}

# Keys are also the art file names under assets/ (see docs/ASSETS.md).
const PLACEABLES := {
	"rest_table_small_01": {"zone": "restaurant", "cost": 30, "name": "ITEM_TABLE", "color": Color("b8793f")},
	"rest_stove_01": {"zone": "restaurant", "cost": 80, "name": "ITEM_STOVE", "color": Color("6b6f78")},
	"farm_fence_01": {"zone": "farm", "cost": 20, "name": "ITEM_FENCE", "color": Color("d9c7a0")},
	"farm_coop_01": {"zone": "farm", "cost": 120, "name": "ITEM_COOP", "color": Color("b5503c")},
}

static func placeables_for(zone: String) -> Array[String]:
	var out: Array[String] = []
	for id in PLACEABLES:
		if PLACEABLES[id].zone == zone:
			out.append(id)
	return out
