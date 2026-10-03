extends Node2D

# Shallow water and foam that gently pulse along the scene's shore. The shoreline comes from the coast
# field (SceneLayout.coast_segments), so it follows the real outline of the land.
var time := 0.0
var zone := "restaurant"
var _segments: Array = []   # [from_world, to_world, outward_normal_world]

func set_zone(z: String) -> void:
	zone = z
	_build()
	queue_redraw()

func _build() -> void:
	_segments.clear()
	for seg in GameState.layout_for(zone).coast_segments():
		var a := Iso.cell_to_world_f(seg[0])
		var b := Iso.cell_to_world_f(seg[1])
		var n_world := (Iso.cell_to_world_f(seg[0] + seg[2]) - a).normalized()
		_segments.append([a, b, n_world])

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	if _segments.is_empty():
		_build()
	for band in range(3):
		var col_alpha := 0.34 - band * 0.09
		var width := 14.0 + band * 6.0
		for i in range(_segments.size()):
			var seg: Array = _segments[i]
			var phase := time * 0.9 + band + i * 0.07
			var offset := 2.0 + band * 11.0 + 3.0 * sin(phase) + width * 0.5
			var alpha := col_alpha * (0.75 + 0.25 * sin(time * 1.1 + band * 1.7 + i * 0.05))
			draw_line(seg[0] + seg[2] * offset, seg[1] + seg[2] * offset, Color(0.75, 0.95, 0.95, alpha), width)
	for i in range(0, _segments.size(), 2):
		var seg: Array = _segments[i]
		var wob := 2.0 + 3.0 * sin(time * 1.4 + i * 0.8)
		var fade := 0.5 + 0.5 * sin(time * 2.0 + i * 1.3)
		draw_line(seg[0] + seg[2] * wob, seg[1] + seg[2] * wob, Color(1, 1, 1, 0.35 + 0.45 * fade), 2.4)
