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

# ---- Placed things (furniture, plants, plots...) sit on a finer grid: every cell is SUB x SUB "units".
# Unit (2c, 2c) is the top-left quarter of cell (c, c); a thing's origin and size are counted in units.
# Land, walls, trees and the map editor's tiles stay in whole cells.
const SUB := 2

static func cell_of_unit(u: Vector2i) -> Vector2i:
	return Vector2i(floori(u.x / float(SUB)), floori(u.y / float(SUB)))

# World point of a unit's top-left corner.
static func unit_corner(u: Vector2i) -> Vector2:
	return cell_to_world_f(Vector2(u) / float(SUB) - Vector2(0.5, 0.5))

# World point at the middle of a whole cell when `u` is the cell's top-left unit (a unit's own centre is a quarter cell off).
static func unit_to_world(u: Vector2i) -> Vector2:
	return cell_to_world_f(Vector2(u) / float(SUB))

# Unit under a world point.
static func world_to_unit(p: Vector2) -> Vector2i:
	var f := world_to_cell_f(p) + Vector2(0.5, 0.5)
	return Vector2i(floori(f.x * SUB), floori(f.y * SUB))

# Size in world pixels of a footprint of `sz` units.
static func unit_width(sz: Vector2i) -> float:
	return sz.x * TILE_W / SUB

static func unit_height(sz: Vector2i) -> float:
	return sz.y * TILE_H / SUB

static func unit_center(origin: Vector2i, sz: Vector2i) -> Vector2:
	return unit_corner(origin) + Vector2(unit_width(sz), unit_height(sz)) * 0.5

# Corners in order: top-left, top-right, bottom-right, bottom-left.
static func unit_corners(origin: Vector2i, sz: Vector2i) -> PackedVector2Array:
	var a := unit_corner(origin)
	var w := unit_width(sz)
	var h := unit_height(sz)
	return PackedVector2Array([a, a + Vector2(w, 0), a + Vector2(w, h), a + Vector2(0, h)])

# ---- Draw order. Everything that stands on the ground (furniture, trees, and later people) is sorted by where its feet
# are: `foot` is the point at the middle of the bottom edge of what it stands on, in unit coordinates (float). A larger
# key is nearer the viewer and is drawn later. A thing's size or picture never changes its key, only where it stands.
static func depth_key(foot: Vector2) -> float:
	return foot.y * 1000.0 + foot.x

# Key of a thing with a footprint: the row of its bottom edge, and its left end as the tie-break so that two things on the same
# row are ordered left to right. `origin` and `sz` are in units.
static func footprint_depth(origin: Vector2i, sz: Vector2i) -> float:
	return depth_key(Vector2(origin.x, origin.y + sz.y))
