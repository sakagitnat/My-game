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

# Art for things that look different from each side: [front, left, back, right]; a name ending "|flip" is the same picture mirrored.
# Items without an entry use their own art for every turn. (The chair needs only front, back and one side: the right side is the left one mirrored.)
const FACING_ART := {
	"rest_chair_01": ["rest_chair_down_01", "rest_chair_side_01", "rest_chair_up_01", "rest_chair_side_01|flip"],
}

# {art: sprite id, flip: bool} to draw `id` turned to `facing`.
static func facing_art(id: String, facing: int) -> Dictionary:
	var list: Array = FACING_ART.get(id, [])
	if list.size() != 4:
		return {"art": id, "flip": false}
	var name: String = list[facing % 4]
	if name.ends_with("|flip"):
		return {"art": name.trim_suffix("|flip"), "flip": true}
	return {"art": name, "flip": false}

static func placeable_color(id: String) -> Color:
	return PLACEABLE_COLOR.get(id, FALLBACK_COLOR)

static func crop_color(crop: String) -> Color:
	return CROP_COLOR.get(crop, Color("8fcf6a"))

static func obstacle(kind: String) -> Dictionary:
	return OBSTACLE.get(kind, {"art": "", "scale": 1.0})
