class_name Noise2D
extends RefCounted

# Small deterministic value noise; the same inputs always give the same layout.
static func hash2(x: int, y: int, seed_v: int = 0) -> float:
	var h: int = (x * 374761393 + y * 668265263 + seed_v * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0

static func value(x: float, y: float, seed_v: int = 0) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - xi
	var fy := y - yi
	var u := fx * fx * (3.0 - 2.0 * fx)
	var v := fy * fy * (3.0 - 2.0 * fy)
	var a := hash2(xi, yi, seed_v)
	var b := hash2(xi + 1, yi, seed_v)
	var c := hash2(xi, yi + 1, seed_v)
	var d := hash2(xi + 1, yi + 1, seed_v)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)
