extends Node2D

# Shallow water and foam that gently pulse along the island's shore.
var time := 0.0

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var gs := GameState.GRID_SIZE
	var k := Iso.footprint_corners(Vector2i.ZERO, gs)
	var center := (k[0] + k[2]) * 0.5
	for i in range(4):
		var a := k[i]
		var b := k[(i + 1) % 4]
		var normal := (b - a).orthogonal().normalized()
		if normal.dot((a + b) * 0.5 - center) < 0.0:
			normal = -normal
		for band in range(3):
			var near := 2.0 + band * 11.0 + 3.0 * sin(time * 0.9 + band + i)
			var far := near + 14.0 + band * 6.0
			var alpha := (0.34 - band * 0.09) * (0.75 + 0.25 * sin(time * 1.1 + band * 1.7 + i))
			draw_colored_polygon(PackedVector2Array([a + normal * near, b + normal * near, b + normal * far, a + normal * far]), Color(0.75, 0.95, 0.95, alpha))
		var length := a.distance_to(b)
		var steps := int(length / 16.0)
		for s in range(steps):
			var t0 := float(s) / steps
			var t1 := t0 + 0.55 / steps
			var wob := 2.0 + 3.0 * sin(time * 1.4 + s * 0.8 + i)
			var fade := 0.5 + 0.5 * sin(time * 2.0 + s * 1.3)
			draw_line(a.lerp(b, t0) + normal * wob, a.lerp(b, t1) + normal * wob, Color(1, 1, 1, 0.35 + 0.45 * fade), 2.4)
