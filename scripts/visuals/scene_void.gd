class_name SceneVoid
extends Node2D

# What lies beyond the edge of a map: dark ground, except where the map's own border is water, where the sea
# simply carries on. Drawn below the terrain. Reads the layout only.
const REACH := 7000.0
const COLOR := Color("0b1519")

var zone := "restaurant"

func set_zone(z: String) -> void:
	zone = z
	queue_redraw()

func _draw() -> void:
	var lay := GameState.layout_for(zone)
	var w := lay.cells.x
	var h := lay.cells.y
	# Each side walks its border cells; a run of non-water cells becomes one strip pushed outward.
	var sides := [
		{"cells": func(i: int) -> Vector2i: return Vector2i(i, 0), "n": Vector2(0, -1), "count": w, "a": Vector2(-0.5, -0.5), "step": Vector2(1, 0)},
		{"cells": func(i: int) -> Vector2i: return Vector2i(w - 1, i), "n": Vector2(1, 0), "count": h, "a": Vector2(w - 0.5, -0.5), "step": Vector2(0, 1)},
		{"cells": func(i: int) -> Vector2i: return Vector2i(i, h - 1), "n": Vector2(0, 1), "count": w, "a": Vector2(-0.5, h - 0.5), "step": Vector2(1, 0)},
		{"cells": func(i: int) -> Vector2i: return Vector2i(0, i), "n": Vector2(-1, 0), "count": h, "a": Vector2(-0.5, -0.5), "step": Vector2(0, 1)},
	]
	for side in sides:
		var run_start := -1
		for i in range(side.count + 1):
			var solid: bool = i < side.count and _is_ground(lay, side.cells.call(i))
			if solid and run_start < 0:
				run_start = i
			elif not solid and run_start >= 0:
				_strip(side.a + side.step * run_start, side.a + side.step * i, side.n)
				run_start = -1
	# corners that are not water get a wedge so the strips of two sides meet
	var corners := [
		[Vector2i(0, 0), Vector2(-0.5, -0.5), Vector2(0, -1), Vector2(-1, 0)],
		[Vector2i(w - 1, 0), Vector2(w - 0.5, -0.5), Vector2(0, -1), Vector2(1, 0)],
		[Vector2i(w - 1, h - 1), Vector2(w - 0.5, h - 0.5), Vector2(0, 1), Vector2(1, 0)],
		[Vector2i(0, h - 1), Vector2(-0.5, h - 0.5), Vector2(0, 1), Vector2(-1, 0)],
	]
	for c in corners:
		if _is_ground(lay, c[0]):
			var p := Iso.cell_to_world_f(c[1])
			var d1 := (Iso.cell_to_world_f(c[1] + c[2]) - p).normalized() * REACH
			var d2 := (Iso.cell_to_world_f(c[1] + c[3]) - p).normalized() * REACH
			draw_colored_polygon(PackedVector2Array([p, p + d1, p + d1 + d2, p + d2]), COLOR)

# Ground, not shore: a border cell next to the water lets the sea carry on, so a ragged coast does not leave stripes.
func _is_ground(lay: SceneLayout, c: Vector2i) -> bool:
	return lay.tile_at(c) != SceneLayout.Tile.WATER and lay.edge_distance(c) >= 3

# A strip along the border from cell-space point a to b, pushed outward along grid direction n.
func _strip(a: Vector2, b: Vector2, n: Vector2) -> void:
	var pa := Iso.cell_to_world_f(a)
	var pb := Iso.cell_to_world_f(b)
	var out := (Iso.cell_to_world_f(a + n) - pa).normalized() * REACH
	draw_colored_polygon(PackedVector2Array([pa, pb, pb + out, pa + out]), COLOR)
