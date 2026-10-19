class_name Animal
extends Node3D

# A little round animal (the cat chef, the guests) built from simple shapes: one mesh for the body and head, and four legs
# that swing when it walks. walk_along() sends it along a path; `arrived` fires at the end.

signal arrived

const SPECIES := {
	"cat": {"fur": Color("f0a050"), "light": Color("fff3e2"), "ears": "point", "tail": "long", "nose": Color("e88a8a")},
	"bunny": {"fur": Color("f5f0ea"), "light": Color("ffffff"), "ears": "long", "tail": "puff", "nose": Color("f2a0b0")},
	"bear": {"fur": Color("9a6a48"), "light": Color("d9b48c"), "ears": "round", "tail": "puff", "nose": Color("3a2a24")},
	"pig": {"fur": Color("f4b4b4"), "light": Color("fbd0cc"), "ears": "point", "tail": "curl", "nose": Color("e8909a")},
	"duck": {"fur": Color("fdf6e3"), "light": Color("fffbe9"), "ears": "none", "tail": "puff", "nose": Color("f0a030")},
}

var species := "cat"
var chef := false
var shirt := Color("7fb8e0")
var speed := 1.1
var path: Array[Vector3] = []
var body: Node3D
var legs: Array[Node3D] = []
var _t := 0.0

func setup(kind: String, is_chef: bool = false, shirt_col: Color = Color("7fb8e0")) -> Animal:
	species = kind
	chef = is_chef
	shirt = shirt_col
	_build()
	return self

func _build() -> void:
	var s: Dictionary = SPECIES[species]
	var fur: Color = s.fur
	var light: Color = s.light
	body = Node3D.new()
	add_child(body)
	var b := MeshBatch.new()
	# body: a soft pear, shirt or apron on the front
	b.ball(Vector3(0, 0.36, 0), Vector3(0.24, 0.22, 0.2), fur)
	b.ball(Vector3(0, 0.33, 0.06), Vector3(0.17, 0.16, 0.15), shirt if not chef else Color.WHITE)
	if chef:
		b.box(Vector3(-0.13, 0.2, 0.17), Vector3(0.13, 0.46, 0.2), Color.WHITE)           # apron
		b.box(Vector3(-0.05, 0.42, 0.19), Vector3(0.05, 0.47, 0.215), Color("d9483b"))    # red neckerchief knot
	# head: big and round (a chibi), muzzle, eyes, nose, cheeks
	var hy := 0.78
	b.add("ball_hi", Transform3D(Basis.from_scale(Vector3(0.52, 0.46, 0.46)), Vector3(0, hy, 0)), fur)
	b.ball(Vector3(0, hy - 0.08, 0.18), Vector3(0.13, 0.09, 0.07), light)
	for sx in [-1.0, 1.0]:
		b.ball(Vector3(sx * 0.1, hy + 0.03, 0.2), Vector3(0.032, 0.045, 0.02), Color("2a2230"))
		b.ball(Vector3(sx * 0.09, hy + 0.05, 0.215), Vector3(0.01, 0.012, 0.006), Color.WHITE)
		b.ball(Vector3(sx * 0.17, hy - 0.06, 0.17), Vector3(0.04, 0.025, 0.015), Color("f29a9a"))
	if species == "duck":
		b.ball(Vector3(0, hy - 0.06, 0.24), Vector3(0.09, 0.035, 0.08), s.nose)
	elif species == "pig":
		b.ball(Vector3(0, hy - 0.05, 0.23), Vector3(0.07, 0.05, 0.035), s.nose)
	else:
		b.ball(Vector3(0, hy - 0.05, 0.245), Vector3(0.03, 0.022, 0.018), s.nose)
	# ears
	match str(s.ears):
		"point":
			for sx in [-1.0, 1.0]:
				b.add("cone", Transform3D(Basis(Vector3.BACK, -sx * 0.35) * Basis.from_scale(Vector3(0.16, 0.18, 0.1)), Vector3(sx * 0.14, hy + 0.24, 0)), fur)
				b.add("cone", Transform3D(Basis(Vector3.BACK, -sx * 0.35) * Basis.from_scale(Vector3(0.09, 0.11, 0.06)), Vector3(sx * 0.14, hy + 0.23, 0.03)), Color("f2b0b0"))
		"long":
			for sx in [-1.0, 1.0]:
				b.ball(Vector3(sx * 0.08, hy + 0.36, -0.02), Vector3(0.055, 0.2, 0.04), fur)
				b.ball(Vector3(sx * 0.08, hy + 0.36, 0.01), Vector3(0.03, 0.15, 0.02), Color("f7c0cc"))
		"round":
			for sx in [-1.0, 1.0]:
				b.ball(Vector3(sx * 0.17, hy + 0.2, -0.02), Vector3(0.07, 0.07, 0.04), fur)
				b.ball(Vector3(sx * 0.17, hy + 0.2, 0.0), Vector3(0.04, 0.04, 0.02), light)
	# a chef's hat
	if chef:
		b.cyl(Vector3(0, hy + 0.17, -0.01), 0.13, 0.14, Color.WHITE)
		b.ball(Vector3(0, hy + 0.36, -0.01), Vector3(0.19, 0.12, 0.17), Color.WHITE)
	# tail
	match str(s.tail):
		"long":
			var prev := Vector3(0, 0.3, -0.18)
			for i in 5:
				var nxt := prev + Vector3(0.03, 0.06 + i * 0.012, -0.05 + i * 0.02)
				b.rod(prev, nxt, 0.035, fur if i < 4 else light)
				prev = nxt
		"puff":
			b.ball(Vector3(0, 0.3, -0.2), Vector3.ONE * 0.07, light)
		"curl":
			b.ball(Vector3(0, 0.36, -0.2), Vector3(0.05, 0.05, 0.03), fur)
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = MeshBatch.material(0.7)
	body.add_child(mi)
	# legs (and little arms) on pivots so they can swing
	for spec in [[-0.1, 0.16, 0.06, 0.16, true], [0.1, 0.16, 0.06, 0.16, true], [-0.23, 0.44, 0.05, 0.16, false], [0.23, 0.44, 0.05, 0.16, false]]:
		var pivot := Node3D.new()
		pivot.position = Vector3(spec[0], spec[1], 0)
		var lb := MeshBatch.new()
		lb.ball(Vector3(0, -float(spec[3]) * 0.5, 0), Vector3(spec[2], spec[3] * 0.6, spec[2]), fur if spec[4] or species != "cat" or not chef else Color.WHITE)
		if spec[4]:
			lb.ball(Vector3(0, -float(spec[3]) + 0.01, 0.03), Vector3(0.06, 0.035, 0.08), light)
		var lmi := MeshInstance3D.new()
		lmi.mesh = lb.mesh()
		lmi.material_override = mi.material_override
		pivot.add_child(lmi)
		(body if not spec[4] else self).add_child(pivot)
		legs.append(pivot)

func walk_along(points: Array[Vector3]) -> void:
	path = points.duplicate()

func is_walking() -> bool:
	return not path.is_empty()

func _process(delta: float) -> void:
	_t += delta
	if path.is_empty():
		body.position.y = 0.01 * sin(_t * 2.5)                     # breathing
		for l in legs:
			l.rotation.x = lerpf(l.rotation.x, 0.0, 0.2)
		return
	var target: Vector3 = path[0]
	var to := target - position
	to.y = 0.0
	var step := speed * delta
	if to.length() <= step:
		position = Vector3(target.x, position.y, target.z)
		path.remove_at(0)
		if path.is_empty():
			arrived.emit()
		return
	var dir := to.normalized()
	position += dir * step
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 0.25)
	var phase := _t * 11.0
	body.position.y = absf(sin(phase)) * 0.06
	body.rotation.z = sin(phase) * 0.06
	legs[0].rotation.x = sin(phase) * 0.6
	legs[1].rotation.x = -sin(phase) * 0.6
	legs[2].rotation.x = -sin(phase) * 0.5
	legs[3].rotation.x = sin(phase) * 0.5
