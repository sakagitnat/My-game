extends Node

# Top-down art only (docs/ART_TOPDOWN.md). No art is shipped yet: the code-drawn stand-ins show until the new set arrives.
const DIRS: Array[String] = ["td/tiles", "td/walls", "td/modular", "td/furniture", "td/props", "td/deco", "td/obstacles", "td/farm", "td/chars", "td/icons", "ui", "app"]

var _cache: Dictionary = {}

# Returns the AI-made PNG if it exists, otherwise null so callers draw a placeholder.
func get_tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var tex: Texture2D = null
	for d in DIRS:
		var p := "res://assets/%s/%s.png" % [d, id]
		if ResourceLoader.exists(p):
			tex = load(p) as Texture2D
			break
	_cache[id] = tex
	return tex
