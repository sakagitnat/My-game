class_name Iso
extends RefCounted

# One cell is a 2:1 diamond. Cells are small; objects cover several cells and
# land is bought in PARCEL x PARCEL blocks (see WorldGrid).
const TILE_W := 64.0
const TILE_H := 32.0

static func cell_to_world(c: Vector2i) -> Vector2:
	return cell_to_world_f(Vector2(c))

# Float cell coordinates; (i, j) is the centre of cell (i, j), (i - 0.5, j - 0.5) its top corner.
static func cell_to_world_f(c: Vector2) -> Vector2:
	return Vector2((c.x - c.y) * TILE_W * 0.5, (c.x + c.y) * TILE_H * 0.5)

static func world_to_cell(p: Vector2) -> Vector2i:
	var a := p.x / (TILE_W * 0.5)
	var b := p.y / (TILE_H * 0.5)
	return Vector2i(floori((a + b) * 0.5 + 0.5), floori((b - a) * 0.5 + 0.5))

# Screen width of a footprint of the given cell size (also the width art is scaled to).
static func footprint_width(sz: Vector2i) -> float:
	return (sz.x + sz.y) * TILE_W * 0.5

static func footprint_height(sz: Vector2i) -> float:
	return (sz.x + sz.y) * TILE_H * 0.5

# Centre of the footprint whose top-left cell is `origin`.
static func footprint_center(origin: Vector2i, sz: Vector2i) -> Vector2:
	return cell_to_world_f(Vector2(origin) + Vector2(sz - Vector2i.ONE) * 0.5)

# Corners in order: top, right, bottom, left.
static func footprint_corners(origin: Vector2i, sz: Vector2i) -> PackedVector2Array:
	var o := Vector2(origin) - Vector2(0.5, 0.5)
	return PackedVector2Array([
		cell_to_world_f(o),
		cell_to_world_f(o + Vector2(sz.x, 0)),
		cell_to_world_f(o + Vector2(sz)),
		cell_to_world_f(o + Vector2(0, sz.y)),
	])
