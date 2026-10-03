class_name Iso
extends RefCounted

# Cell <-> world coordinates for the top-down (3/4, Stardew-style) view. The class keeps its old name so the rest of the
# code did not have to change: it used to be an isometric diamond, now a cell is a plain square. Objects cover several
# cells and land is bought in PARCEL x PARCEL blocks (see WorldGrid). One cell is 64 px (art is drawn at 128 px per cell).
const TILE_W := 64.0
const TILE_H := 64.0

static func cell_to_world(c: Vector2i) -> Vector2:
	return cell_to_world_f(Vector2(c))

# Float cell coordinates; (i, j) is the centre of cell (i, j), (i - 0.5, j - 0.5) its top-left corner.
static func cell_to_world_f(c: Vector2) -> Vector2:
	return Vector2(c.x * TILE_W, c.y * TILE_H)

static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE_W + 0.5), floori(p.y / TILE_H + 0.5))

# Inverse of cell_to_world_f: float cell coordinates under a world point.
static func world_to_cell_f(p: Vector2) -> Vector2:
	return Vector2(p.x / TILE_W, p.y / TILE_H)

# On-screen width of a footprint of the given cell size (also the width art is scaled to).
static func footprint_width(sz: Vector2i) -> float:
	return sz.x * TILE_W

static func footprint_height(sz: Vector2i) -> float:
	return sz.y * TILE_H

# Centre of the footprint whose top-left cell is `origin`.
static func footprint_center(origin: Vector2i, sz: Vector2i) -> Vector2:
	return cell_to_world_f(Vector2(origin) + Vector2(sz - Vector2i.ONE) * 0.5)

# Corners in order: top-left, top-right, bottom-right, bottom-left.
static func footprint_corners(origin: Vector2i, sz: Vector2i) -> PackedVector2Array:
	var o := Vector2(origin) - Vector2(0.5, 0.5)
	return PackedVector2Array([
		cell_to_world_f(o),
		cell_to_world_f(o + Vector2(sz.x, 0)),
		cell_to_world_f(o + Vector2(sz)),
		cell_to_world_f(o + Vector2(0, sz.y)),
	])
