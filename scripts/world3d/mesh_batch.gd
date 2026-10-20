class_name MeshBatch
extends RefCounted

# Collects many coloured shapes (boxes, balls, cylinders, cones) into one mesh, so the whole static world is a few draw calls
# (an iPad in a browser cannot afford one draw call per leaf). Every shape carries its colour in its vertices; one material
# that reads vertex colours draws them all.

static var _shapes: Dictionary = {}

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()

static func _shape(kind: String) -> Array:
	if _shapes.has(kind):
		return _shapes[kind]
	var m: PrimitiveMesh
	match kind:
		"box":
			m = BoxMesh.new()
		"ball":
			var s := SphereMesh.new()
			s.radial_segments = 12
			s.rings = 6
			m = s
		"ball_hi":
			var s := SphereMesh.new()
			s.radial_segments = 18
			s.rings = 9
			m = s
		"cyl":
			var c := CylinderMesh.new()
			c.height = 1.0                       # unit shapes: the default cylinder is 2 m tall
			c.radial_segments = 10
			c.rings = 1
			m = c
		"cone":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.height = 1.0
			c.radial_segments = 8
			c.rings = 1
			m = c
	var arrays := m.get_mesh_arrays()
	_shapes[kind] = arrays
	return arrays

# Adds `kind` (a unit shape: box 1 x 1 x 1, ball radius 0.5, cylinder radius 0.5 height 1, centred) moved by `xf`.
# `lumpy` pushes vertices in and out a little (leaves, rocks); `seed` varies the lumps.
func add(kind: String, xf: Transform3D, col: Color, lumpy: float = 0.0, seed: int = 0) -> void:
	var a := _shape(kind)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var base := verts.size()
	var basis_n := xf.basis.inverse().transposed()
	for i in v.size():
		var p := v[i]
		if lumpy > 0.0:
			var h := Noise2D.value(p.x * 3.1 + p.y * 1.7 + seed * 0.37, p.z * 3.1 - p.y * 2.3 + seed * 0.11, seed)
			p += n[i] * (h - 0.5) * lumpy
		verts.append(xf * p)
		normals.append((basis_n * n[i]).normalized())
		colors.append(col)
	for i in idx:
		indices.append(base + i)

# Shorthands in world terms: a box between two corners, a ball, an upright cylinder or cone.
func box(lo: Vector3, hi: Vector3, col: Color) -> void:
	add("box", Transform3D(Basis.from_scale(hi - lo), (lo + hi) * 0.5), col)

func ball(c: Vector3, r: Vector3, col: Color, lumpy: float = 0.0, seed: int = 0) -> void:
	add("ball", Transform3D(Basis.from_scale(r * 2.0), c), col, lumpy, seed)

func cyl(bottom: Vector3, r: float, h: float, col: Color) -> void:
	add("cyl", Transform3D(Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), bottom + Vector3(0, h * 0.5, 0)), col)

func cone(bottom: Vector3, r: float, h: float, col: Color) -> void:
	add("cone", Transform3D(Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), bottom + Vector3(0, h * 0.5, 0)), col)

# A cylinder from a to b (a branch, a leg, a rail).
func rod(a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var d := b - a
	var up := d.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	var basis := Basis(side * r * 2.0, up * d.length(), fwd * r * 2.0)
	add("cyl", Transform3D(basis, (a + b) * 0.5), col)

func is_empty() -> bool:
	return verts.is_empty()

func mesh() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

static var _material: ShaderMaterial

# One material for everything batched: the colour is in the vertices (sRGB); shaders/toon3d.gdshader gives the soft
# painted light. A vertex alpha below 1 makes leaves sway.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/toon3d.gdshader")
	return _material

# A colour that sways in the wind (leaves, stalks): `amount` 0..1.
static func swaying(c: Color, amount: float = 0.5) -> Color:
	return Color(c.r, c.g, c.b, 1.0 - amount * 0.5)
