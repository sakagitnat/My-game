class_name ArtCatalog
extends RefCounted

# Look-only data: placeholder colours and sprite sizing. Game rules (cost, level, footprint) live in Catalog.
const FALLBACK_COLOR := Color("b8793f")

const PLACEABLE_COLOR := {
	"rest_table_small_01": Color("b8793f"),
	"rest_stove_01": Color("6b6f78"),
	"farm_plot_01": Color("6b4a2f"),
	"farm_fence_01": Color("d9c7a0"),
	"farm_coop_01": Color("b5503c"),
}

const CROP_COLOR := {
	"wheat": Color("e6c35c"),
	"tomato": Color("d9453b"),
	"cabbage": Color("8fcf6a"),
}

# `art`: sprite id under assets/. `scale`: sprite width in cells.
const OBSTACLE := {
	"tree": {"art": "obs_tree_01", "scale": 2.0},
	"rock": {"art": "obs_rock_01", "scale": 1.0},
	"bush": {"art": "obs_bush_01", "scale": 1.0},
}

static func placeable_color(id: String) -> Color:
	return PLACEABLE_COLOR.get(id, FALLBACK_COLOR)

static func crop_color(crop: String) -> Color:
	return CROP_COLOR.get(crop, Color("8fcf6a"))

static func obstacle(kind: String) -> Dictionary:
	return OBSTACLE.get(kind, {"art": "", "scale": 1.0})
