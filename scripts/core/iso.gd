class_name Iso
extends RefCounted

const TILE_W := 128.0
const TILE_H := 64.0

static func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2((c.x - c.y) * TILE_W * 0.5, (c.x + c.y) * TILE_H * 0.5)

static func world_to_cell(p: Vector2) -> Vector2i:
	var a := p.x / (TILE_W * 0.5)
	var b := p.y / (TILE_H * 0.5)
	return Vector2i(floori((a + b) * 0.5 + 0.5), floori((b - a) * 0.5 + 0.5))
