class_name ArtCatalog
extends RefCounted

# Look-only data: placeholder colours and sprite sizing. Game rules (cost, level, footprint) live in Catalog.
const FALLBACK_COLOR := Color("b8793f")

const PLACEABLE_COLOR := {
	"rest_table_small_01": Color("b8793f"),
	"rest_stove_01": Color("6b6f78"),
	"rest_vase_small_01": Color("5b8fb0"),
	"rest_vase_large_01": Color("4f7aa0"),
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

# The picture's own box, separate from the room the thing reserves (Catalog "size") and from where it blocks walking.
# By default the picture is as wide as its footprint, centred on it, and its bottom edge sits on the footprint's bottom edge
# (the foot). An entry here changes that: "w" is the picture's width in units (more than the footprint lets a roof or a crown
# stick out sideways without squeezing the picture), "dx" / "dy" move it in units (right / down). The picture keeps its shape.
const ART_BOX := {}

static func art_box(id: String) -> Dictionary:
	return ART_BOX.get(id, {})

# Where a picture is drawn: `foot` is the middle of the bottom edge of the footprint, `fp_width` its width, `tex_size` the
# picture's size in pixels, `box` an ART_BOX entry (or {}). Units are Iso.TILE_W / Iso.SUB px wide.
static func sprite_rect(box: Dictionary, tex_size: Vector2, foot: Vector2, fp_width: float) -> Rect2:
	var unit := Iso.TILE_W / float(Iso.SUB)
	var w := float(box.w) * unit if box.has("w") else fp_width
	var s := tex_size * (w / tex_size.x)
	var origin := foot + Vector2(float(box.get("dx", 0.0)), float(box.get("dy", 0.0))) * unit
	return Rect2(origin - Vector2(s.x * 0.5, s.y), s)

# A second, smaller look for a share of the trees (`share` of them, picked per cell): a young tree as tall as a person.
# Used only when its art exists; heights (docs/ART_TOPDOWN.md): big tree 3 blocks, small tree 2, bush 1, rock half a block.
const OBSTACLE_ALT := {
	"tree": {"art": "obs_tree_02", "scale": 1.0, "share": 0.35},
}

# Art for things that look different from each side: [front, left, back, right]; a name ending "|flip" is the same picture mirrored.
# Items without an entry use their own art for every turn. (The chair needs only front, back and one side: the right side is the left one mirrored.)
# Which things need which pictures (the right side is always the left one mirrored, so at most three are drawn):
#   shared  one picture for every turn: table, vases, stool, crate, bin, rug, plant pot, floor lamp (they look the same from every side)
#   three   front, side (left) and back: chair, stove, bench / long table (side = the 1 x 2 / 2 x 1 footprint turned)
#   fixed   cannot be turned (against a wall or with one front only): kitchen modules, fridge, shelf, register, menu sign
# A turn whose own picture is missing falls back to the front picture.
const FACING_ART := {
	"rest_stove_01": ["rest_stove_01", "rest_stove_side_01", "rest_stove_back_01", "rest_stove_side_01|flip"],
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

# How tall a thing is, in blocks (one block is one cell, 64 game px): a counter or table 1, a fridge or door 2, a wall 3.
# The art follows it: a thing's canvas is 128 x blocks px of height plus 64 px for every cell of depth (the top surface seen at an angle).
const HEIGHT_BLOCKS := {"rest_table_small_01": 1.0, "rest_stove_01": 1.0, "farm_coop_01": 3.0, "farm_fence_01": 0.75, "rest_vase_small_01": 0.5, "rest_vase_large_01": 0.9}

static func height_blocks(id: String) -> float:
	return HEIGHT_BLOCKS.get(id, 1.0)

# Where the top surface of a surface object (a table) lies on its picture, as fractions of the footprint's height from the back:
# things standing on it are drawn on that band, further back on the table = higher on the screen (art spec: table top at y 8..68 of 128).
const SURFACE_BAND := {"rest_table_small_01": Vector2(0.02, 0.5)}
const DEFAULT_SURFACE_BAND := Vector2(0.02, 0.5)
const HOVER := 36.0   # a ghost that is not over any table hovers this high, in game pixels

static func surface_band(surface_id: String) -> Vector2:
	return SURFACE_BAND.get(surface_id, DEFAULT_SURFACE_BAND)

static func placeable_color(id: String) -> Color:
	return PLACEABLE_COLOR.get(id, FALLBACK_COLOR)

static func crop_color(crop: String) -> Color:
	return CROP_COLOR.get(crop, Color("8fcf6a"))

static func obstacle(kind: String) -> Dictionary:
	return OBSTACLE.get(kind, {"art": "", "scale": 1.0})

# The look of an obstacle on one cell: the smaller variant for part of the trees (roll is a 0..1 hash of the cell) when its art exists.
static func obstacle_look(kind: String, roll: float, has_art: Callable) -> Dictionary:
	var alt: Dictionary = OBSTACLE_ALT.get(kind, {})
	if not alt.is_empty() and roll < float(alt.share) and bool(has_art.call(str(alt.art))):
		return alt
	return obstacle(kind)
