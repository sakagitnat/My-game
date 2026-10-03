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
	"tree": {"art": "obs_tree_01", "scale": 2.6},
	"rock": {"art": "obs_rock_01", "scale": 1.3},
	"bush": {"art": "obs_bush_01", "scale": 1.6},
}

const OBSTACLE_VARIANTS := {"tree": 3, "rock": 2, "bush": 2}

# Visual-only selection; independent of the gameplay RNG and stable across reloads.
static func obstacle_sprite(kind: String, cell: Vector2i) -> String:
	if not OBSTACLE_VARIANTS.has(kind):
		return str(obstacle(kind).art)
	var count: int = OBSTACLE_VARIANTS[kind]
	var index := posmod(cell.x * 73856093 ^ cell.y * 19349663, count) + 1
	return "obs_%s_%02d" % [kind, index]

static func placeable_color(id: String) -> Color:
	return PLACEABLE_COLOR.get(id, FALLBACK_COLOR)

static func crop_color(crop: String) -> Color:
	return CROP_COLOR.get(crop, Color("8fcf6a"))

static func obstacle(kind: String) -> Dictionary:
	return OBSTACLE.get(kind, {"art": "", "scale": 1.0})


const DISH_ART := {
	"wheat_porridge": "dish_wheat_porridge",
	"omelet": "dish_omelet",
	"tomato_soup": "dish_soup",
	"cabbage_salad": "dish_salad",
}

static func dish_art(dish: String) -> String:
	return DISH_ART.get(dish, "")
